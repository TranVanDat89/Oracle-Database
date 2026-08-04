```sql
    CREATE USER brazilian_ecommerce IDENTIFIED BY oracle123;

    GRANT ALL PRIVILEGES TO brazilian_ecommerce;

    CREATE TABLESPACE ecommerce
    DATAFILE '/opt/oracle/oradata/ecommerce.dbf'
    SIZE 500M
    AUTOEXTEND ON
    NEXT 50M
    MAXSIZE 5G
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO;
```