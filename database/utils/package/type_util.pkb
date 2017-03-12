CREATE OR REPLACE PACKAGE BODY type_util IS

   --
   -- dedup (1) - objects
   --
   FUNCTION dedup(in_t_obj IN t_obj_type) RETURN t_obj_type IS
      t_result t_obj_type := t_obj_type();
   BEGIN
      IF in_t_obj IS NOT NULL AND in_t_obj.count > 0 THEN
         <<distinct_objects>>
         FOR r_obj IN (
            SELECT DISTINCT
                   owner,
                   object_type,
                   object_name
              FROM TABLE(in_t_obj)
         ) LOOP
            t_result.extend;
            t_result(t_result.count) := obj_type (
                                           owner       => r_obj.owner,
                                           object_type => r_obj.object_type,
                                           object_name => r_obj.object_name
                                        );
         END LOOP distinct_objects;
      END IF;
      RETURN t_result;
   END dedup;

   --
   -- dedup (2) - columns
   --
   FUNCTION dedup(in_t_col IN t_col_type) RETURN t_col_type IS
      t_result t_col_type := t_col_type();
   BEGIN
      IF in_t_col IS NOT NULL AND in_t_col.count > 0 THEN
         <<distinct_columns>>
         FOR r_col IN (
            SELECT DISTINCT
                   owner,
                   object_type,
                   object_name,
                   column_name
              FROM TABLE(in_t_col)
         ) LOOP
            t_result.extend;
            t_result(t_result.count) := col_type (
                                           owner       => r_col.owner,
                                           object_type => r_col.object_type,
                                           object_name => r_col.object_name,
                                           column_name => r_col.column_name
                                        );
         END LOOP distinct_columns;
      END IF;
      RETURN t_result;
   END dedup;

   --
   -- dedup (3) - column lineage
   --
   FUNCTION dedup(in_t_col_lineage IN t_col_lineage_type) RETURN t_col_lineage_type IS
      t_result t_col_lineage_type := t_col_lineage_type();
   BEGIN
      IF in_t_col_lineage IS NOT NULL AND in_t_col_lineage.count > 0 THEN
         <<distinct_column_lineage>>
         FOR r_col IN (
            SELECT DISTINCT
                   from_owner,
                   from_object_type,
                   from_object_name,
                   from_column_name,
                   to_owner,
                   to_object_type,
                   to_object_name,
                   to_column_name
              FROM TABLE(in_t_col_lineage)
         ) LOOP
            t_result.extend;
            t_result(t_result.count) := col_lineage_type (
                                           from_owner       => r_col.from_owner,
                                           from_object_type => r_col.from_object_type,
                                           from_object_name => r_col.from_object_name,
                                           from_column_name => r_col.from_column_name,
                                           to_owner         => r_col.to_owner,
                                           to_object_type   => r_col.to_object_type,
                                           to_object_name   => r_col.to_object_name,
                                           to_column_name   => r_col.to_column_name
                                        );
         END LOOP distinct_column_lineage;
      END IF;
      RETURN t_result;
   END dedup;   
      
END type_util;
/
