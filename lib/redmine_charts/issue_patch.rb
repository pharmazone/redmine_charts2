module RedmineCharts
  module IssuePatch

    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        after_save :chart_update_issue_done_ratio, :chart_update_issue_status
        before_destroy :chart_remove_issue
      end

    end

    def self.add_chart_done_ratio(project_id, issue_id, status_id, done_ratio, date)
        row = ChartDoneRatio.where( {:issue_id => issue_id, :day => 0, :week => 0, :month => 0} ).first

        done_ratio = IssueStatus.find(status_id).is_closed? ? 100 : done_ratio

        if row
          if row.done_ratio != done_ratio
            row.done_ratio = done_ratio
            row.save
          end
        elsif done_ratio > 0
          ChartDoneRatio.create(:issue_id => issue_id, :project_id => project_id, :day => 0, :week => 0, :month => 0, :done_ratio => done_ratio)
        end

        day = RedmineCharts::RangeUtils.format_day(date)
        week = RedmineCharts::RangeUtils.format_week(date)
        month = RedmineCharts::RangeUtils.format_month(date)

        row = ChartDoneRatio.where({:issue_id => issue_id, :day => day, :week => week, :month => month}).first

        if row
          if row.done_ratio != done_ratio
            row.done_ratio = done_ratio
            row.save
          end
        elsif done_ratio > 0
          ChartDoneRatio.create(:issue_id => issue_id, :project_id => project_id, :day => day, :week => week, :month => month, :done_ratio => done_ratio)
        end
      end

      def self.add_chart_issue_status(project_id, issue_id, status_id, date)
        day = RedmineCharts::RangeUtils.format_day(date)
        week = RedmineCharts::RangeUtils.format_week(date)
        month = RedmineCharts::RangeUtils.format_month(date)

        row = ChartIssueStatus.where({:issue_id => issue_id, :day => day, :week => week, :month => month}).first

        if row
          if row.status_id != status_id
            row.status_id = status_id
            row.save
          end
        else
          ChartIssueStatus.create(:issue_id => issue_id, :project_id => project_id, :day => day, :week => week, :month => month, :status_id => status_id)
        end
      end

    module InstanceMethods

      def chart_remove_issue
        ChartDoneRatio.delete_all(:issue_id => self.id)
        ChartIssueStatus.delete_all(:issue_id => self.id)
        ChartTimeEntry.delete_all(:issue_id => self.id)
      end

      def chart_update_issue_done_ratio
        RedmineCharts::IssuePatch.add_chart_done_ratio(self.project_id, self.id, self.status_id, self.done_ratio, Time.now)
      end

      def chart_update_issue_status
        RedmineCharts::IssuePatch.add_chart_issue_status(self.project_id, self.id, self.status_id, Time.now)
      end

    end

  end
end