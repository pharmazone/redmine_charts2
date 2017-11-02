require 'redmine_charts/utils'

# Configuring routing for plugin's controllers.
RedmineApp::Application.routes.draw do
  scope '/charts' do
    get "/burndown2/:project_id" => "charts_burndown2#index"
    get "/burndown/:project_id" => "charts_burndown#index"
    get "/ratio/:project_id" => "charts_ratio#index"
    get "/timeline/:project_id" => "charts_timeline#index"
    get "/deviation/:project_id" => "charts_deviation#index"
    get "/issue/:project_id" => "charts_issue#index"
    
    post "/destroy_saved_condition/:controller" => 'charts#destroy_saved_condition'
  end
end