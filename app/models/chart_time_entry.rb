class ChartTimeEntry < ActiveRecord::Base

  belongs_to :issue

  def self.get_timeline(raw_group, raw_conditions, range)
    group = RedmineCharts::GroupingUtils.to_column(raw_group, "chart_time_entries")

    conditions = {}

    raw_conditions.each do |c, v|
      column_name = RedmineCharts::ConditionsUtils.to_column(c, "chart_time_entries")
      conditions[column_name] = v if v and column_name
    end

    joins = "left join issues on issues.id = issue_id"

    unless range
      row = first(:select => "month, week, day", :joins => joins, :conditions => ["day > 0 AND chart_time_entries.project_id in (?)", conditions['chart_time_entries.project_id']], :readonly => true, :order => "1 asc, 2 asc, 3 asc")

      if row
        range = RedmineCharts::RangeUtils.propose_range({ :month => row.month, :week => row.week, :day => row.day })
      else
        range = RedmineCharts::RangeUtils.default_range
      end
    end

    range = RedmineCharts::RangeUtils.prepare_range(range)

    range[:column] = RedmineCharts::ConditionsUtils.to_column(range[:range], "chart_time_entries")

    select = "#{range[:column]} as range_value, '#{range[:range]}' as range_type, sum(logged_hours) as logged_hours, sum(entries) as entries, '#{raw_group}' as grouping"

    if group
      select << ", #{group} as group_id"
    else
      select << ", 0 as group_id"
    end

    conditions[range[:column]] = range[:min]..range[:max]

    grouping = "#{range[:column]}"
    grouping << ", #{group}" if group

    rows = joins(joins).select(select).where(conditions).group(grouping).readonly(true).order("1 asc, 6 asc").all()

    rows.each do |row|
      row.group_id = '0' unless row.group_id
    end

    [rows, range]
  end

  def self.get_aggregation_for_issue(raw_conditions, range)
    group = RedmineCharts::GroupingUtils.to_column(:issue_id, "chart_time_entries")

    conditions = {}

    raw_conditions.each do |c, v|
      column_name = RedmineCharts::ConditionsUtils.to_column(c, "chart_time_entries")
      conditions[column_name] = v if v and column_name
    end

    range = RedmineCharts::RangeUtils.prepare_range(range)
    
    range[:column] = RedmineCharts::ConditionsUtils.to_column(range[:range], "chart_time_entries")

    conditions[range[:column]] = '1'..range[:max]

    joins = "left join issues on issues.id = issue_id"
    select = "sum(logged_hours) as logged_hours, chart_time_entries.issue_id as issue_id"

    rows = joins(joins).select(select).where(conditions).group(group).readonly(true).order("1 desc, 2 asc").all()

    issues = {}

    rows.each do |row|
      issues[row.issue_id.to_i] = row.logged_hours.to_f
    end

    issues
  end

  def self.get_aggregation(raw_group, raw_conditions)
    raw_group ||= :user_id
    group = RedmineCharts::GroupingUtils.to_column(raw_group, "chart_time_entries")

    conditions = {}

    raw_conditions.each do |c, v|
      column_name = RedmineCharts::ConditionsUtils.to_column(c, "chart_time_entries")
      conditions[column_name] = v if v and column_name
    end

    conditions[:day] = 0
    conditions[:week] = 0
    conditions[:month] = 0

    joins = "left join issues on issues.id = issue_id"

    select = "sum(logged_hours) as logged_hours, sum(entries) as entries, #{group} as group_id, '#{raw_group}' as grouping"

    if group == 'chart_time_entries.issue_id'
      select << ", issues.estimated_hours as estimated_hours, issues.subject as subject"
      group << ", issues.estimated_hours, issues.subject"

      if RedmineCharts.has_sub_issues_functionality_active
        select << ", issues.root_id, issues.parent_id"
        group << ", issues.root_id, issues.parent_id"
      else
        select << ", chart_time_entries.issue_id as root_id, null as parent_id"
      end
    else
      select << ", 0 as estimated_hours"
    end

    rows = all(:joins => joins, :select => select, :conditions => conditions, :readonly => true, :group => group, :order => "1 desc, 3 asc")

    rows.each do |row|
      row.group_id = '0' unless row.group_id
      row.estimated_hours = '0' unless row.estimated_hours
    end
  end

end
