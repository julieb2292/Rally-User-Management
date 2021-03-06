#include for rally json library gem
require 'rally_api'
require 'csv'

#Setting custom headers
$headers = RallyAPI::CustomHttpHeader.new()
$headers.name           = "Ruby User Permissions Summary Report"
$headers.vendor         = "Rally Labs"
$headers.version        = "0.10"

#API Version
$wsapi_version          = "1.40"

# constants
$my_base_url            = "https://rally1.rallydev.com/slm"
$my_username            = "user@company.com"
$my_password            = "password"
$my_headers             = $headers
$my_page_size           = 200
$my_limit               = 50000

$type_workspacepermission = "WorkspacePermission"
$type_projectpermission   = "ProjectPermission"
$output_fields            =  %w{UserID LastName FirstName DisplayName Type Workspace WorkspaceOrProjectName Role ObjectID}
$my_output_file           = "user_permissions_summary.txt"
$my_delim                 = "\t"

if $my_delim == nil then $my_delim = "," end

def strip_role_from_permission(str)
  # Removes the role from the Workspace,ProjectPermission String so we're left with just the
  # Workspace/Project Name
  str.gsub(/\bAdmin|\bUser|\bEditor|\bViewer/,"").strip
end

begin

  # Load (and maybe override with) my personal/private variables from a file...
  my_vars= File.dirname(__FILE__) + "/my_vars.rb"
  if FileTest.exist?( my_vars ) then require my_vars end

  #==================== Making a connection to Rally ====================
  config                  = {:base_url => $my_base_url}
  config[:username]       = $my_username
  config[:password]       = $my_password
  config[:version]        = $wsapi_version
  config[:headers]        = $my_headers #from RallyAPI::CustomHttpHeader.new()

  puts "Connecting to Rally: #{$my_base_url} as #{$my_username}..."

  @rally = RallyAPI::RallyRestJson.new(config)

  #==================== Querying Rally ==========================
  user_query = RallyAPI::RallyQuery.new()
  user_query.type = :user
  user_query.fetch = "UserName,FirstName,LastName,DisplayName,UserPermissions,Name,Role,Workspace,ObjectID,Project,ObjectID"
  user_query.page_size = 200 #optional - default is 200
  user_query.limit = 50000 #optional - default is 99999
  user_query.order = "UserName Asc"

  # Query for users
  puts "Querying users..."

  results = @rally.find(user_query)

  # Start output of summary
  # Output CSV header
  summary_csv = CSV.open($my_output_file, "w", {:col_sep => $my_delim})
  summary_csv << $output_fields

  # Set a default value for workspace_name
  workspace_name = "N/A"

  number_users = results.total_result_count
  puts "Found #{number_users} users."

  count = 1
  notify_increment = 25

  # loop through all users and output permissions summary
  puts "Summarizing users and writing permission summary output file..."

  results.each do | this_user |

    notify_remainder=count%notify_increment
    if notify_remainder==0 then puts "Processed #{count} of #{number_users} users" end
    count+=1

    user_permissions = this_user.UserPermissions
    user_permissions.each do |this_permission|

      permission_type = this_permission._type
      if this_permission._type == $type_workspacepermission
        workspace_name = strip_role_from_permission(this_permission.Name)
        workspace_project_obj = this_permission["Workspace"]
      else
        workspace_project_obj = this_permission["Project"]
      end

      # Grab the ObjectID
      object_id = workspace_project_obj["ObjectID"]

      # Grab workspace or project name from permission name
      workspace_project_name = strip_role_from_permission(this_permission.Name)

      output_record = []
      output_record << this_user.UserName
      output_record << this_user.LastName
      output_record << this_user.FirstName
      output_record << this_user.DisplayName
      output_record << this_permission._type
      output_record << workspace_name
      output_record << workspace_project_name
      output_record << this_permission.Role
      output_record << object_id
      summary_csv << output_record
    end
    if user_permissions.length == 0
      output_record = []
      output_record << this_user.UserName
      output_record << this_user.LastName
      output_record << this_user.FirstName
      output_record << this_user.DisplayName
      output_record << "N/A"
      output_record << "N/A"
      output_record << "N/A"
      output_record << "N/A"
      output_record << "N/A"
      summary_csv << output_record
    end
  end

  puts "Done! Permission summary written to #{$my_output_file}."

rescue Exception => ex
  puts ex.backtrace
end