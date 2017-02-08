#!/bin/sh

rm test-mutex.log -f
ruby ./caller_exception.rb &
ruby ./caller_exception.rb &
ruby ./caller_exception.rb &
