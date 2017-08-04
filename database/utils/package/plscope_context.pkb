CREATE OR REPLACE PACKAGE BODY plscope_context IS

   co_namespace CONSTANT sys.all_context.namespace%TYPE := 'PLSCOPE';

   --
   -- set_attr
   --
   PROCEDURE set_attr (
      in_name  IN VARCHAR2,
      in_value IN VARCHAR2
   ) IS
   BEGIN
      sys.dbms_session.set_context(
         namespace => co_namespace,
         attribute => in_name, 
         value     => in_value
      );
   END set_attr;
   
   --
   -- remove_attr
   --
   PROCEDURE remove_attr (
      in_name  IN VARCHAR2
   ) IS
   BEGIN
      sys.dbms_session.clear_context(
         namespace => co_namespace,
         attribute => in_name
      );
   END remove_attr;
   
   --
   -- remove_all
   --
   PROCEDURE remove_all IS
   BEGIN
      sys.dbms_session.clear_all_context(
         namespace => co_namespace
      );
   END remove_all;
      
END plscope_context;
/
