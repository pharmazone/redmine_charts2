class ChartsBurndown2Controller < ChartsController

  unloadable

  protected

  def get_data
    @conditions[:fixed_version_ids] ||= get_current_fixed_version_in(@project)

    version = unless @conditions[:fixed_version_ids].empty?
      Version.where({:id => @conditions[:fixed_version_ids][0]}).first
    end

    unless version
      { :error => :charts_error_no_version }          
    else
      start_date = version.start_date || version.created_on.to_date
      end_date = version.effective_date ? version.effective_date.to_date : Time.now.to_date

      @range = RedmineCharts::RangeUtils.propose_range_for_two_dates(start_date, end_date)

      total_estimated_hours, total_logged_hours, total_remaining_hours, total_predicted_hours, total_done, total_velocities = get_data_for_burndown_chart

      max = 0
      total_estimated = 0
      remaining = []

      @range[:keys].each_with_index do |key, index|
        max = total_velocities[index] if max < total_velocities[index]
        max = total_remaining_hours[index] if max < total_remaining_hours[index]

        if RedmineCharts::RangeUtils.date_from_day(key).to_time <= Time.now
          remaining << [total_remaining_hours[index], l(:charts_burndown2_hint_remaining, { :remaining_hours => RedmineCharts::Utils.round(total_remaining_hours[index]), :work_done => total_done[index] > 0 ? Integer(total_done[index]) : 0 })]
        end
      end

      velocity = []

      @range[:keys].size.times do |index|
        velocity << [total_velocities[index], l(:charts_burndown2_hint_velocity, { :remaining_hours => RedmineCharts::Utils.round(total_velocities[index])})]
      end

      velocity[velocity.size-1] = [0, l(:charts_burndown2_hint_velocity, { :remaining_hours => 0.0})]

      sets = [
        [l(:charts_burndown2_group_velocity), velocity],
        [l(:charts_burndown2_group_burndown), remaining],
      ]

      {
        :labels => @range[:labels],
        :count => @range[:keys].size,
        :max => max > 0 ? max : 1,
        :sets => sets
      }
    end

  end

  def get_data_for_burndown_chart
    conditions = {}

    @conditions.each do |c, v|
      column_name = RedmineCharts::ConditionsUtils.to_column(c, 'issues')
      column_name = 'issues.id' if column_name == 'issues.issue_id'
      conditions[column_name] = v if v and column_name
    end

    issues = Issue.where(conditions).all

    # remove parent issues
    issues_children = []
    issues.each do |issue|
      issues_children << issue.parent_id if RedmineCharts.has_sub_issues_functionality_active and issue.parent_id
    end
    issues.to_a.delete_if {|issue| issues_children.include?(issue[:id])}

    rows, @range = ChartTimeEntry.get_timeline(:issue_id, @conditions, @range)

    current_logged_hours_per_issue = ChartTimeEntry.get_aggregation_for_issue(@conditions, @range)

    done_ratios_per_issue = ChartDoneRatio.get_timeline_for_issue(@conditions, @range)

    total_estimated_hours = Array.new(@range[:keys].size, 0)
    total_logged_hours = Array.new(@range[:keys].size, 0)
    total_remaining_hours = Array.new(@range[:keys].size, 0)
    total_predicted_hours = Array.new(@range[:keys].size, 0)
    total_done = Array.new(@range[:keys].size, 0)
    total_velocities = Array.new(@range[:keys].size, 0)
    issues_per_date = Array.new(@range[:keys].size, 0)
    logged_hours_per_issue = {}
    estimated_hours_per_issue = {}
    velocities_per_issue = {}

    logged_hours_per_issue[0] = Array.new(@range[:keys].size, current_logged_hours_per_issue[0] || 0)
    estimated_hours_per_issue[0] ||= Array.new(@range[:keys].size, 0)

    issues.each do |issue|
      logged_hours_per_issue[issue.id] ||= Array.new(@range[:keys].size, current_logged_hours_per_issue[issue.id] || 0)
      estimated_hours_per_issue[issue.id] ||= Array.new(@range[:keys].size, 0)
      velocities_per_issue[issue.id] ||= Array.new(@range[:keys].size, 0)

      issue_start_date = issue.created_on.to_date
      range_start_date = issue.created_on.to_date
      if issue.start_date
        issue_start_date = issue.start_date if issue.start_date > issue.created_on.to_date
        range_start_date = issue.start_date if issue.start_date < issue.created_on.to_date
      end

      issue_start_key = [RedmineCharts::RangeUtils.format_date_with_unit(issue_start_date, @range[:range]), @range[:keys].first].max
      range_start_key = [RedmineCharts::RangeUtils.format_date_with_unit(range_start_date, @range[:range]), @range[:keys].first].max
      range_end_key = issue.due_date ? [RedmineCharts::RangeUtils.format_date_with_unit(issue.due_date, @range[:range]), @range[:keys].last].min : @range[:keys].last

      range_start_date = RedmineCharts::RangeUtils.date_from_unit(range_start_key, @range[:range])
      range_end_date = RedmineCharts::RangeUtils.date_from_unit(range_end_key, @range[:range])
      range_diff_days = (range_end_date - issue_start_date)

      @range[:keys].each_with_index do |key, i|
        if range_start_key <= key
          if issue.estimated_hours
            if key <= range_end_key
              velocities_per_issue[issue.id][i] =
                (range_diff_days > 0 and key > issue_start_key) ?
                (issue.estimated_hours * (range_end_date - RedmineCharts::RangeUtils.date_from_unit(key, @range[:range])) / range_diff_days) :
                issue.estimated_hours
            end
            estimated_hours_per_issue[issue.id][i] = issue.estimated_hours
          end
          issues_per_date[i] += 1
        end
      end
    end

    rows.each do |row|
      index = @range[:keys].index(row.range_value.to_s)
      (0..(index-1)).each do |i|
        logged_hours_per_issue[row.group_id.to_i][i] -= row.logged_hours.to_f if logged_hours_per_issue[row.group_id.to_i]
      end
    end

    @range[:keys].each_with_index do |key,index|
      estimated_count = 0
      issues.each do |issue|
        logged = logged_hours_per_issue[issue.id] ? logged_hours_per_issue[issue.id][index] : 0
        done_ratio = done_ratios_per_issue[issue.id] ? done_ratios_per_issue[issue.id][index] : 0
        estimated = (done_ratio > 0 and logged > 0) ? (logged/done_ratio*100) : (estimated_hours_per_issue[issue.id] ? estimated_hours_per_issue[issue.id][index] : 0)
        velocity = velocities_per_issue[issue.id] ? velocities_per_issue[issue.id][index] : 0

        total_remaining_hours[index] += estimated * (100-done_ratio) / 100

        total_logged_hours[index] += logged
        total_estimated_hours[index] += estimated
        total_velocities[index] += velocity
        if estimated > 0
          estimated_count += 1
        else
          total_done[index] += done_ratio
        end
      end

      total_logged_hours[index] += logged_hours_per_issue[0][index]

      if issues_per_date[index] > 0
        total_done[index] += (1 - (total_remaining_hours[index] / total_estimated_hours[index])) * 100 * estimated_count if total_estimated_hours[index] > 0
        total_done[index] /= issues_per_date[index]
      end

      total_predicted_hours[index] = total_remaining_hours[index] + total_logged_hours[index]

      total_logged_hours[index] = 0 if total_logged_hours[index] < 0.01
      total_estimated_hours[index] = 0 if total_estimated_hours[index] < 0.01
      total_remaining_hours[index] = 0 if total_remaining_hours[index] < 0.01
      total_done[index] = 0 if total_done[index] < 0.01
      total_predicted_hours[index] = 0 if total_predicted_hours[index] < 0.01
      total_velocities[index] = 0 if total_velocities[index] < 0.01
    end

    [total_estimated_hours, total_logged_hours, total_remaining_hours, total_predicted_hours, total_done, total_velocities]
  end

  def get_title
    l(:charts_link_burndown2)
  end

  def get_help
    l(:charts_burndown2_help)
  end

  def get_x_legend
    l(:charts_burndown2_x)
  end

  def get_y_legend
    l(:charts_burndown2_y)
  end

  def get_conditions_options
    [:fixed_version_ids]
  end

  def get_multiconditions_options
    (RedmineCharts::ConditionsUtils.types - [:activity_ids, :user_ids, :fixed_version_ids, :project_ids]).flatten
  end

  private

  def get_current_fixed_version_in(project)
    version = Version.where({:project_id => project.id}).all().detect do |version|
      version.created_on.to_date <= Date.current && !version.effective_date.nil? && version.effective_date >= Date.current
    end
    if version
      [version.id]
    else
      versions = RedmineCharts::ConditionsUtils.to_options(project, [:fixed_version_ids])[:fixed_version_ids]
      unless versions.nil? || versions.empty?
        [versions.first[1]]
      else
        []
      end
    end
  end

end
