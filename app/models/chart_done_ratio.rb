class ChartDoneRatio < ActiveRecord::Base

  def self.get_timeline_for_issue(raw_conditions, range)
    conditions = {}
    done_ratios = {}

    raw_conditions.each do |c, v|
      column_name = RedmineCharts::ConditionsUtils.to_column(c, "chart_done_ratios")
      conditions[column_name] = v if v and column_name
    end

    range = RedmineCharts::RangeUtils.prepare_range(range)

    range[:column] = RedmineCharts::ConditionsUtils.to_column(range[:range], "chart_done_ratios")

    joins = "left join issues on issues.id = issue_id"
    
    conditions[range[:column]] = range[:min]..range[:max]

    select = "#{range[:column]} as range_value, '#{range[:range]}' as range_type, chart_done_ratios.done_ratio, chart_done_ratios.issue_id"

    #rows = all(:select => select, :joins => joins, :conditions => conditions, :order => '1 asc')
	rows = joins(joins).select(select).where(conditions).order('1 asc').all

    rows.each do |row|
      done_ratios[row.issue_id.to_i] ||= Array.new(range[:keys].size, 0)
      index = range[:keys].index(row.range_value.to_s)
      next unless index
      (index...range[:keys].size).each do |i|
        done_ratios[row.issue_id.to_i][i] = row.done_ratio.to_i
      end
    end

    latest_done_ratio = get_aggregation_for_issue(raw_conditions)

    latest_done_ratio.each do |issue_id, done_ratio|
      done_ratios[issue_id] ||= Array.new(range[:keys].size, done_ratio)
    end

    done_ratios
  end

  def self.get_aggregation_for_issue(raw_conditions)
    conditions = {}
    conditions[:project_id] = raw_conditions[:project_ids]
    conditions[:day] = 0
    conditions[:week] = 0
    conditions[:month] = 0

    rows = where(conditions).all()

    issues = {}

    rows.each do |row|
      issues[row.issue_id.to_i] = row.done_ratio.to_i
    end

    issues
  end

end
