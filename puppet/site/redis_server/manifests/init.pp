class redis_server {
  class { 'redis':
    bind        => '0.0.0.0',
    port        => 6379,
    requirepass => 'secret',
  }
}
