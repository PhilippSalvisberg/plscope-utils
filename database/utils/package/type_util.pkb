create or replace package body type_util is

   --
   -- dedup (1) - objects
   --
   function dedup(in_t_obj in t_obj_type) return t_obj_type is
      t_result t_obj_type := t_obj_type();
   begin
      if in_t_obj is not null and in_t_obj.count > 0 then
         <<distinct_objects>>
         for r_obj in (
            select distinct
                   owner,
                   object_type,
                   object_name
              from table(in_t_obj)
             order by owner, object_type, object_name
         )
         loop
            t_result.extend;
            t_result(t_result.count) := obj_type(
                                           owner       => r_obj.owner,
                                           object_type => r_obj.object_type,
                                           object_name => r_obj.object_name
                                        );
         end loop distinct_objects;
      end if;
      return t_result;
   end dedup;

   --
   -- dedup (2) - columns
   --
   function dedup(in_t_col in t_col_type) return t_col_type is
      t_result t_col_type := t_col_type();
   begin
      if in_t_col is not null and in_t_col.count > 0 then
         <<distinct_columns>>
         for r_col in (
            select distinct
                   owner,
                   object_type,
                   object_name,
                   column_name
              from table(in_t_col)
             order by owner, object_type, object_name, column_name
         )
         loop
            t_result.extend;
            t_result(t_result.count) := col_type(
                                           owner       => r_col.owner,
                                           object_type => r_col.object_type,
                                           object_name => r_col.object_name,
                                           column_name => r_col.column_name
                                        );
         end loop distinct_columns;
      end if;
      return t_result;
   end dedup;

   --
   -- dedup (3) - column lineage
   --
   function dedup(in_t_col_lineage in t_col_lineage_type) return t_col_lineage_type is
      t_result t_col_lineage_type := t_col_lineage_type();
   begin
      if in_t_col_lineage is not null and in_t_col_lineage.count > 0 then
         <<distinct_column_lineage>>
         for r_col in (
            select distinct
                   from_owner,
                   from_object_type,
                   from_object_name,
                   from_column_name,
                   to_owner,
                   to_object_type,
                   to_object_name,
                   to_column_name
              from table(in_t_col_lineage)
             order by from_owner,
                   from_object_type,
                   from_object_name,
                   from_column_name,
                   to_owner,
                   to_object_type,
                   to_object_name,
                   to_column_name
         )
         loop
            t_result.extend;
            t_result(t_result.count) := col_lineage_type(
                                           from_owner       => r_col.from_owner,
                                           from_object_type => r_col.from_object_type,
                                           from_object_name => r_col.from_object_name,
                                           from_column_name => r_col.from_column_name,
                                           to_owner         => r_col.to_owner,
                                           to_object_type   => r_col.to_object_type,
                                           to_object_name   => r_col.to_object_name,
                                           to_column_name   => r_col.to_column_name
                                        );
         end loop distinct_column_lineage;
      end if;
      return t_result;
   end dedup;

end type_util;
/
