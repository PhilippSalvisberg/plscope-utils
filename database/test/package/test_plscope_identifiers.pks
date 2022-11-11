create or replace package test_plscope_identifiers authid current_user is

   --%suite
   --%suitepath(plscope.test)

   --%beforeeach
   procedure set_context;

   --%aftereach
   procedure clear_context;

   --%test
   procedure user_identifiers;
      
   --%test
   procedure plscope_identfiers_model_name;

   --%test
   procedure user_statements;

end test_plscope_identifiers;
/
