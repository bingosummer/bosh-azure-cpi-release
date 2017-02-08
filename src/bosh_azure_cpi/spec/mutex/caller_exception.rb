require 'logger'
require_relative 'FileMutex'

logger = Logger.new('test-mutex.log')
mutex = FileMutex.new("/tmp/test-mutex", logger, 20)
begin
  mutex.synchronize do
    logger.info("#{Process.pid}: The exception process. Do the real work.")
    raise "#{Process.pid}: exception"
  end
rescue => e
  logger.info("#{Process.pid}: #{e}")
end
