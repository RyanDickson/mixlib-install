#
# Author:: Thom May (<thom@chef.io>)
# Author:: Patrick Wright (<patrick@chef.io>)
# Copyright:: Copyright (c) 2015 Chef, Inc.
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

require "mixlib/versioning"

require "mixlib/install/backend"
require "mixlib/install/options"
require "mixlib/install/generator"
require "mixlib/install/generator/bourne"
require "mixlib/install/generator/powershell"

module Mixlib
  class Install

    attr_reader :options

    def initialize(options = {})
      @options = Options.new(options)
    end

    #
    # Fetch artifact metadata information
    #
    # @return [ArtifactInfo] fetched artifact data
    #
    def artifact_info
      Backend.info(options)
    end

    #
    # Returns an install script for the given options
    #
    # @return [String] script for installing with given options
    #
    def install_command
      Generator.install_command(options)
    end

    #
    # Returns the base installation directory for the given options
    #
    # @return [String] the installation directory for the project
    #
    def root
      # This only works for chef and chefdk but they are the only projects
      # we are supporting as of now.
      if options.for_ps1?
        "$env:systemdrive\\opscode\\#{options.product_name}"
      else
        "/opt/#{options.product_name}"
      end
    end

    #
    # Returns the current version of the installed product.
    # Returns nil if the product is not installed.
    #
    def current_version
      # Note that this logic does not work for products other than
      # chef & chefdk since version-manifest is created under the
      # install directory which can be different than the product name (e.g.
      # chef-server -> /opt/opscode). But this is OK for now since
      # chef & chefdk are the only supported products.
      version_manifest_file = if options.for_ps1?
        "$env:systemdrive\\opscode\\#{options.product_name}\\version-manifest.json"
      else
        "/opt/#{options.product_name}/version-manifest.json"
      end

      if File.exist? version_manifest_file
        JSON.parse(File.read(version_manifest_file))["build_version"]
      end
    end

    #
    # Returns true if an upgradable version is available, false otherwise.
    #
    def upgrade_available?
      return true if current_version.nil?

      available_ver = Mixlib::Versioning.parse(artifact_info.first.version)
      current_ver = Mixlib::Versioning.parse(current_version)
      (available_ver > current_ver)
    end

    #
    # Returns the install.sh script
    # Supported context parameters:
    # ------------------
    # base_url [String]
    #   url pointing to the omnitruck to be queried by the script.
    #
    def self.install_sh(context = {})
      Mixlib::Install::Generator::Bourne.install_sh(context)
    end

    #
    # Returns the install.ps1 script
    # Supported context parameters:
    # ------------------
    # base_url [String]
    #   url pointing to the omnitruck to be queried by the script.
    #
    def self.install_ps1(context = {})
      Mixlib::Install::Generator::PowerShell.install_ps1(context)
    end

    #
    # Detects platform, platform_version and architecture on the
    # **current machnie**.
    # Returns a Hash containing the discovered information.
    #
    def self.detect_platform
      if RUBY_PLATFORM =~ /mswin|mingw|windows/
        # For windows we use a single set of parameters since all of our builds
        # are keyed with the same set.
        {
          platform: "windows",
          platform_version: "2008r2",
          architecture: "x64"
        }
      else
        # TODO: execute platform_detection.sh on the machine and return
        # the results as a hash.
      end

    end
  end
end
