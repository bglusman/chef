#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Nuo Yan (<nuo@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/role'

class Roles < Application

  provides :html
  before :login_required
  before :require_admin, :only => [:destroy]

  # GET /roles
  def index
    @role_list =  begin
                   Chef::Role.list()
                  rescue => e
                    Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
                    @_message = {:error => "Could not list roles"}
                    {}
                  end
    render
  end

  # GET /roles/:id
  def show
    @role = begin
              Chef::Role.load(params[:id])
            rescue => e
              Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
              @_message = {:error => "Could not load role #{params[:id]}"}
              Chef::Role.new
            end
    render
  end

  # GET /roles/new
  def new
    begin
      @role = Chef::Role.new
      @available_roles = Chef::Role.list.keys.sort
      @run_list = @role.run_list
      @environments = Chef::Environment.list.keys.sort
      @run_lists = @environments.inject({}) { |run_lists, env| run_lists[env] = @role.env_run_lists[env] ; run_lists}
      @current_env = "_default"
      @available_recipes = list_available_recipes_for(@current_env)
      @existing_run_list_environments = @role.env_run_lists.keys
      # merb select helper has no :include_blank => true, so fix the view in the controller.
      @existing_run_list_environments.unshift('')
      render
    rescue => e
      Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
      @role_list = Chef::Role.list()
      @_message = {:error => "Could not load available recipes, roles, or the run list."}
      render :index
    end
  end

  # GET /roles/:id/edit
  def edit
    begin
      @role = Chef::Role.load(params[:id])
      @available_roles = Chef::Role.list.keys.sort
      @environments = Chef::Environment.list.keys.sort
      @current_env = session[:environment] || "_default"
      @run_lists = @environments.inject({}) { |run_lists, env| run_lists[env] = @role.env_run_lists[env] ; run_lists}
      @existing_run_list_environments = @role.env_run_lists.keys
      # merb select helper has no :include_blank => true, so fix the view in the controller.
      @existing_run_list_environments.unshift('')
      @available_recipes = list_available_recipes_for(@current_env)
    rescue => e
      Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
      @role = Chef::Role.new
      @available_recipes = []
      @available_roles = []
      @run_list = []
      @_message = {:error => "Could not load role #{params[:id]}, the available recipes, roles, or the run list"}
    end
    render
  end

  # POST /roles
  def create
    begin
      @role = Chef::Role.new
      @role.name(params[:name])
      @role.env_run_lists(params[:env_run_lists])
      @role.description(params[:description]) if params[:description] != ''
      @role.default_attributes(Chef::JSON.from_json(params[:default_attributes])) if params[:default_attributes] != ''
      @role.override_attributes(Chef::JSON.from_json(params[:override_attributes])) if params[:override_attributes] != ''
      @role.create
      redirect(url(:roles), :message => { :notice => "Created Role #{@role.name}" })
    rescue => e
      Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
      @available_recipes = list_available_recipes
      @available_roles = Chef::Role.list.keys.sort
      @role = Chef::Role.new
      @role.default_attributes(Chef::JSON.from_json(params[:default_attributes])) if params[:default_attributes] != ''
      @role.override_attributes(Chef::JSON.from_json(params[:override_attributes])) if params[:override_attributes] != ''
      @run_list = Chef::RunList.new.reset!(Array(params[:for_role]))
      @_message = { :error => "Could not create role" }
      render :new
    end
  end

  # PUT /roles/:id
  def update
    begin
      @role = Chef::Role.load(params[:id])
      @role.env_run_lists(params[:env_run_lists])
      @role.description(params[:description]) if params[:description] != ''
      @role.default_attributes(Chef::JSON.from_json(params[:default_attributes])) if params[:default_attributes] != ''
      @role.override_attributes(Chef::JSON.from_json(params[:override_attributes])) if params[:override_attributes] != ''
      @role.save
      @_message = { :notice => "Updated Role" }
      render :show
    rescue => e
      Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
      @available_recipes = list_available_recipes
      @available_roles = Chef::Role.list.keys.sort
      @run_list = Chef::RunList.new.reset!( Array(params[:for_role]))
      Chef::Log.error(@run_list.inspect)
      @role.default_attributes(Chef::JSON.from_json(params[:default_attributes])) if params[:default_attributes] != ''
      @role.override_attributes(Chef::JSON.from_json(params[:override_attributes])) if params[:override_attributes] != ''
      @_message = {:error => "Could not update role #{params[:id]}"}
      render :edit
    end
  end

  # DELETE /roles/:id
  def destroy
    begin
      @role = Chef::Role.load(params[:id])
      @role.destroy
      redirect(absolute_url(:roles), :message => { :notice => "Role #{@role.name} deleted successfully." }, :permanent => true)
    rescue => e
      Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
      @role_list = Chef::Role.list()
      @_message = {:error => "Could not delete role #{params[:id]}"}
      render :index
    end
  end

end
