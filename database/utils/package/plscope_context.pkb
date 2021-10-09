create or replace package body plscope_context is

   co_namespace constant sys.all_context.namespace%type := 'PLSCOPE';

   --
   -- set_attr
   --
   procedure set_attr(
      in_name  in varchar2,
      in_value in varchar2
   ) is
   begin
      sys.dbms_session.set_context(
         namespace => co_namespace,
         attribute => in_name,
         value     => in_value
      );
   end set_attr;
   
   --
   -- remove_attr
   --
   procedure remove_attr(
      in_name in varchar2
   ) is
   begin
      sys.dbms_session.clear_context(
         namespace => co_namespace,
         attribute => in_name
      );
   end remove_attr;
   
   --
   -- remove_all
   --
   procedure remove_all is
   begin
      sys.dbms_session.clear_all_context(
         namespace => co_namespace
      );
   end remove_all;

end plscope_context;
/
