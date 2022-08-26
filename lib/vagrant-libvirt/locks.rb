# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    class LockManager
      def initialize(lockfactory=LocalLockFactory.new)
        @logger = Log4r::Logger.new('vagrant_libvirt::locks')
        @lockfactory = lockfactory
      end

      # Following the pattern in vagrant/lib/environment for creating
      # locks, allowing for them to be created remotely or locally.
      def lock(name="global", **opts)
        flock = nil

        return if !block_given?

        @logger.debug("Attempting to acquire lock: #{name}")
        flock = @lockfactory.create(name)

        while flock.acquire() === false
          @logger.warn("lock in use: #{name}")

          if !opts[:retry]
            raise VagrantPlugins::ProviderLibvirt::Errors::AlreadyLockedError, name: name
          end

          sleep 0.2
        end

        @logger.info("Acquired process lock: #{name}")

        yield
      ensure
        begin
          flock.release() if flock
        rescue IOError
        end
      end
    end

    LOCK_DIR = "/var/tmp/vagrant-libvirt"

    class LocalLockFactory
      class LocalLock
        def initialize(dir, name)
          @f = File.open(File.join(dir, name), "w+", 0775)
        end

        def acquire
          @f.flock(File::LOCK_EX | File::LOCK_NB)
        end

        def release
          @f.close()
        end
      end

      def initialize
        FileUtils.mkdir_p(LOCK_DIR, :mode => 0777)
      end

      def create(name)
        LocalLock.new(LOCK_DIR, name)
      end
    end

    # not ready for usage yet, but defined to ensure API
    class RemoteLockFactory
      class RemoteLock
        def initialize(conn, dir, name)
        end

        def acquire
        end

        def release
        end
      end

      def initialize(conn)
        @conn = conn
      end

      def create(name)
        RemoteLock.new(@conn, LOCK_DIR, name)
      end
    end
  end
end
