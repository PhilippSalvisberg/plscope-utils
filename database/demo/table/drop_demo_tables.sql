declare
   procedure drop_if_exists(in_table_name in varchar2) is
      l_found integer;
      l_sql   varchar2(4000);
   begin
      select count(*)
        into l_found
        from user_tables
       where table_name = upper(in_table_name);
      if l_found > 0 then
         l_sql := 'DROP TABLE '
                  || in_table_name
                  || ' PURGE';
         sys.dbms_output.put_line('executing: ' || l_sql);
         execute immediate l_sql;
         sys.dbms_output.put_line('table '
            || in_table_name
            || ' dropped.');
      end if;
   end drop_if_exists;
begin
   drop_if_exists('emp');
   drop_if_exists('dept');
   drop_if_exists('deptsal');
   drop_if_exists('deptsal_err');
end;
/
