
### Installation
	
1.Add Gemfile file code is as follows

		gem 'svn_record'
		
2.Execute the command 

	rails g svn_record:install
	
3.Add a script file 

	//= require svn_record/change
	
4.Add Style File

	*= require svn_record/site
	
5.Connect svn configuration file
	
	config/configuration.yml
		

### Connect svn configuration file
		After running Access Address
	
		http://localhost:3000/repository/changes
		
### International reference format

		datetime:
		    distance_in_words:
		      half_a_minute: "半分钟"
		      less_than_x_seconds:
		        one: "一秒内"
		        other: "少于 %{count} 秒"
		      x_seconds:
		        one: "一秒"
		        other: "%{count} 秒"
		      less_than_x_minutes:
		        one: "一分钟内"
		        other: "少于 %{count} 分钟"
		      x_minutes:
		        one: "一分钟"
		        other: "%{count} 分钟"
		      about_x_hours:
		        one: "大约一小时"
		        other: "大约 %{count} 小时"
		      x_hours:
		        one:   "1 小时"
		        other: "%{count} 小时"
		      x_days:
		        one: "一天"
		        other: "%{count} 天"
		      about_x_months:
		        one: "大约一个月"
		        other: "大约 %{count} 个月"
		      x_months:
		        one: "一个月"
		        other: "%{count} 个月"
		      about_x_years:
		        one: "大约一年"
		        other: "大约 %{count} 年"
		      over_x_years:
		        one: "超过一年"
		        other: "超过 %{count} 年"
		      almost_x_years:
		        one:   "将近 1 年"
		        other: "将近 %{count} 年"


