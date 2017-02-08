require 'fcntl'

# Lock
BOSH_LOCK_EXCEPTION_TIMEOUT        = 'timeout'
BOSH_LOCK_EXCEPTION_LOCK_NOT_FOUND = 'lock_not_found'

class FileMutex
  def initialize(file_path, logger, expired = 60)
    @file_path = file_path
    @logger = logger
    @expired = expired
  end

  def synchronize
    if lock
      yield
      unlock
    else
      raise BOSH_LOCK_EXCEPTION_TIMEOUT unless wait
    end
  end

  def update()
    File.open(@file_path, 'wb') { |f|
      f.write("InProgress")
    }
  rescue => e
    raise BOSH_LOCK_EXCEPTION_LOCK_NOT_FOUND, e
  end

  private

  def lock()
    if File.exists?(@file_path)
      if Time.new() - File.mtime(@file_path) > @expired
        File.delete(@file_path)
        @logger.debug("The lock `#{@file_path}' exists, but timeouts.")
        raise BOSH_LOCK_EXCEPTION_TIMEOUT
      else
        @logger.debug("The lock `#{@file_path}' exists")
        return false
      end
    else
      begin
        fd = IO::sysopen(@file_path, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT) # Using O_EXCL, creation fails if the file exists
        f = IO.open(fd)
        f.syswrite("InProgress")
        @logger.debug("The lock `#{@file_path}' is created")
      rescue => e
        @logger.error("Failed to create the lock file `#{@file_path}'. Error: #{e.inspect}\n#{e.backtrace.join("\n")}")
        return false
      ensure
        f.close unless f.nil?
      end
      return true
    end
  end

  def wait()
    loop do
      return true unless File.exists?(@file_path)
      break if Time.new() - File.mtime(@file_path) > @expired
      sleep(1)
    end
    return false
  end

  def unlock()
    File.delete(@file_path)
  rescue => e
    raise BOSH_LOCK_EXCEPTION_LOCK_NOT_FOUND, e
  end
end
