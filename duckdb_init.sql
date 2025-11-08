CREATE SECRET s3miniosecret(type s3, scope 's3://opdi', use_ssl false, key_id 'minioadmin', secret 'minioadmin', url_style 'path', endpoint 'minio:9000');
