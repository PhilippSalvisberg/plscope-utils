create or replace package test_plscope_identifiers is

   --%suite
   --%suitepath(plscope.test)

   --%test
   procedure user_identifiers;
      
   --%test
   procedure user_statements;

end test_plscope_identifiers;
/
