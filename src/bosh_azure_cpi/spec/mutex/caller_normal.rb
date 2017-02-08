require 'logger'
require_relative 'FileMutex'

logger = Logger.new('test-mutex.log')
mutex = FileMutex.new("/tmp/test-mutex", logger, 20)
begin
  mutex.synchronize do
    sleep(10)
    logger.info("#{Process.pid}: The normal process. Do the real work.")
  end
rescue => e
  logger.info("#{Process.pid}: #{e}")
end
