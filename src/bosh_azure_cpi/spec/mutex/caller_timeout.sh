#!/bin/sh

rm test-mutex.log -f
ruby ./caller_timeout.rb &
ruby ./caller_timeout.rb &
ruby ./caller_timeout.rb &
