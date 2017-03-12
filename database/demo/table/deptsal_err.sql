BEGIN
   sys.dbms_errlog.create_error_log(
      dml_table_name     => 'deptsal',
      err_log_table_name => 'deptsal_err', 
      skip_unsupported   => TRUE
   );
END;
/