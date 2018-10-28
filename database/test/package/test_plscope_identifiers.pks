CREATE OR REPLACE PACKAGE test_plscope_identifiers IS

   --%suite
   --%suitepath(plscope.test)

   --%test
   PROCEDURE user_identifiers;
      
   --%test
   PROCEDURE user_statements;


END test_plscope_identifiers;
/
