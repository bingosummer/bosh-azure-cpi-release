* Run `./caller_normal.sh`, you will get the logs from `test-mutex.log`.

  ```
  D, [2017-02-08T03:22:59.314105 #11851] DEBUG -- : The lock `/tmp/test-mutex' is created
  D, [2017-02-08T03:22:59.315301 #11850] DEBUG -- : The lock `/tmp/test-mutex' exists
  D, [2017-02-08T03:22:59.316500 #11849] DEBUG -- : The lock `/tmp/test-mutex' exists
  I, [2017-02-08T03:23:09.314276 #11851]  INFO -- : 11851: The normal process. Do the real work.
  ```

* Run `./caller_timeout.sh`, you will get the logs from `test-mutex.log`.

  ```
  D, [2017-02-08T03:25:04.862909 #11918] DEBUG -- : The lock `/tmp/test-mutex' is created
  D, [2017-02-08T03:25:04.870071 #11917] DEBUG -- : The lock `/tmp/test-mutex' exists
  D, [2017-02-08T03:25:04.870231 #11916] DEBUG -- : The lock `/tmp/test-mutex' exists
  I, [2017-02-08T03:25:24.873068 #11916]  INFO -- : 11916: timeout
  I, [2017-02-08T03:25:24.873537 #11917]  INFO -- : 11917: timeout
  I, [2017-02-08T03:25:29.863087 #11918]  INFO -- : 11918: The timeout process. Do the real work.
  ```

* Run `./caller_exception.sh`, you will get the logs from `test-mutex.log`.

  ```
  D, [2017-02-08T03:26:52.098971 #12004] DEBUG -- : The lock `/tmp/test-mutex' is created
  I, [2017-02-08T03:26:52.099009 #12004]  INFO -- : 12004: The exception process. Do the real work.
  I, [2017-02-08T03:26:52.099038 #12004]  INFO -- : 12004: 12004: exception
  D, [2017-02-08T03:26:52.101293 #12003] DEBUG -- : The lock `/tmp/test-mutex' exists
  D, [2017-02-08T03:26:52.104594 #12002] DEBUG -- : The lock `/tmp/test-mutex' exists
  I, [2017-02-08T03:27:12.104245 #12003]  INFO -- : 12003: timeout
  I, [2017-02-08T03:27:12.107891 #12002]  INFO -- : 12002: timeout
  ```
