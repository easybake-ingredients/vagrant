Drop .chef/plugins/knife/source_ingredient_vagrant.rb
into your .chef/plugins/knife directory and run:

```
knife source ingredient vagrant
```

:file_cache_path and :data_bag_path must writable and might need to be set in your knife.rb

The latest available versions of vagrant will be downloaded into
your file_cache_path and your data bag path will get a vagrant directory
created which will be populated with data bag items for each version
of vagrant that is available.

