require 'gooddata'

GoodData.logging_http_on
GoodData.connect
GoodData.use('y561hr3vlivqerg4t5ix0nrvwaa2kczn') # <<<--- REPLACE
# GoodData.logging_http_on
project = GoodData.project


old_date_dim_name = "(Account Start Date)" # <<<--- REPLACE
new_date_dim_name = "(account)"   # <<<--- REPLACE

old_date_dim = []
list_of_attributes = project.attributes.to_a

list_of_attributes.each do |a|
  #puts a.title
  p a.title if a.title.include?(old_date_dim_name)
  old_date_dim << a if a.title.include?(old_date_dim_name)
  #puts old_date_dim
end

metrics = project.metrics.to_a
#puts old_date_dim.title
old_date_dim.each do |old_date|
  puts old_date.title
  # new_date = GoodData::Attribute.find_first_by_title(old_date.title.sub old_date_dim_name, new_date_dim_name);
  new_date = list_of_attributes.find {|a| a.title == old_date.title.sub(old_date_dim_name, new_date_dim_name)}
  puts new_date.title
  # old_date_label = old_date.primary_label;
  # new_date_label = new_date.primary_label;

  # replace in all metrics
  
  begin
    metrics.each do |metric| 
      if metric.contain?(old_date)
        # metric.replace(old_date, new_date)
        # metric.save
        puts "metric replaced #{old_date} with #{new_date}"
      end
    end
  rescue
 	  puts "something went wrong"
  end
  # replace in all reports
  # reports = project.reports;
  # reports.pmap do |report|
  #   #puts report
  #   if report.using?(old_date)
  #     # rd = report.latest_report_definition
  #     # rd.replace(old_date, new_date)
  #     # rd.replace(old_date_label, new_date_label)
  #     # rd.save
  #     puts "metric replaced #{old_date} with #{new_date}"
  #   end
  # end
end