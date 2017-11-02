module RedmineCharts
  module TimeEntryPatch

    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        before_save :chart_update_time_entry
        before_destroy :chart_remove_time_entry
      end

    end

    def self.add_chart_time_entry(project_id, issue_id, user_id, activity_id, hours, date)
      return if hours == 0

      day = RedmineCharts::RangeUtils.format_day(date)
      week = RedmineCharts::RangeUtils.format_week(date)
      month = RedmineCharts::RangeUtils.format_month(date)

      row = ChartTimeEntry.where( {:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => day, :week => week, :month => month} ).first

      if row
        row.logged_hours += hours
        row.entries += 1
        row.save
      else
        ChartTimeEntry.create(:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => day, :week => week, :month => month, :logged_hours => hours, :entries => 1)
      end

      row = ChartTimeEntry.where({:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => 0, :week => 0, :month => 0}).first()

      if row
        row.logged_hours += hours
        row.entries += 1
        row.save
      else
        ChartTimeEntry.create(:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => 0, :week => 0, :month => 0, :logged_hours => hours, :entries => 1)
      end
    end

    def self.remove_chart_time_entry(project_id, issue_id, user_id, activity_id, hours, date)
      if hours and hours > 0
        day = RedmineCharts::RangeUtils.format_day(date)
        week = RedmineCharts::RangeUtils.format_week(date)
        month = RedmineCharts::RangeUtils.format_month(date)

        row = ChartTimeEntry.where({:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => day, :week => week, :month => month}).first()

        if row
          row.logged_hours -= hours
          row.entries -= 1

          if row.entries == 0
            row.destroy
          else
            row.save
          end
        end

        row = ChartTimeEntry.where({:issue_id => issue_id, :project_id => project_id, :activity_id => activity_id, :user_id => user_id, :day => 0, :week => 0, :month => 0}).first

        if row
          row.logged_hours -= hours
          row.entries -= 1

          if row.entries == 0
            row.destroy
          else
            row.save
          end
        end
      end
    end

    module InstanceMethods

      def chart_remove_time_entry
        return if self.hours == 0

        day = RedmineCharts::RangeUtils.format_day(self.spent_on)
        week = RedmineCharts::RangeUtils.format_week(self.spent_on)
        month = RedmineCharts::RangeUtils.format_month(self.spent_on)

        row = ChartTimeEntry.where({:issue_id => self.issue_id, :project_id => self.project_id, :activity_id => self.activity_id, :user_id => self.user_id, :day => day, :week => week, :month => month}).first

        if row
          row.logged_hours -= self.hours
          row.entries -= 1

          if row.entries == 0
            row.destroy
          else
            row.save
          end
        end
      end

      def chart_update_time_entry
        RedmineCharts::TimeEntryPatch.remove_chart_time_entry(self.project_id_was, self.issue_id_was, self.user_id_was, self.activity_id_was, self.hours_was, self.spent_on_was)
        RedmineCharts::TimeEntryPatch.add_chart_time_entry(self.project_id, self.issue_id, self.user_id, self.activity_id, self.hours, self.spent_on)
      end

    end

  end
end