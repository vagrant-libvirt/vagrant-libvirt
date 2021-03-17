require 'open3'
require 'tmpdir'

module VagrantPlugins
  module ProviderLibvirt
    VERSION_FILE = File.dirname(__FILE__) + "/version"

    GIT_ARCHIVE_VERSION = "$Format:%H %D$"

    HOMEPAGE = 'https://github.com/vagrant-libvirt/vagrant-libvirt'

    def self.get_version
      if File.exist?(VERSION_FILE)
        # built gem
        version = File.read(VERSION_FILE)
      elsif self.inside_git_repository
        # local repo
        git_version = `git describe --tags`
        version = self.version_from_describe(git_version)
      elsif !GIT_ARCHIVE_VERSION.start_with?('$Format')
        # archive - format string replaced during export
        hash, refs = GIT_ARCHIVE_VERSION.split(' ', 2)

        tag = refs.split(',').select { |ref| ref.strip.start_with?("tag:") }.first
        if tag != nil
          # tagged
          version = tag.strip.split(' ').last
        else
          version = ""
          # arbitrary branch/commit
          Dir.mktmpdir do |dir|
            stdout_and_stderr, status = Open3.capture2e("git -C #{dir} clone --bare #{HOMEPAGE}")
            raise "failed to clone original to resolve version: #{stdout_and_stderr}" unless status.success?

            stdout_and_stderr, status = Open3.capture2e("git --git-dir=#{dir}/vagrant-libvirt.git describe --tags #{hash}")
            raise "failed to determine version for #{hash}: #{stdout_and_stderr}" unless status.success?

            version = version_from_describe(stdout_and_stderr)
          end

          # in this case write the version file to avoid cloning a second time
          File.write(VERSION_FILE, version)
        end
      else
        # no idea
        version = "9999"
      end

      return version.freeze
    end

    def self.write_version
      File.write(VERSION_FILE, self.get_version)
    end

    private

    def self.inside_git_repository
      _, status = Open3.capture2e("git rev-parse --git-dir")

      status.success?
    end

    def self.version_from_describe(describe)
      version_parts = describe.split('-').first(2) # drop the git sha if it exists
      if version_parts.length > 1
        # increment the patch number so that this is marked as a pre-release of the
        # next possible release
        main_version_parts = Gem::Version.new(version_parts[0]).segments
        main_version_parts[-1] = main_version_parts.last + 1
        version_parts = main_version_parts + ["pre", version_parts[1]]
      end
      version = version_parts.join(".")
    end
  end
end
