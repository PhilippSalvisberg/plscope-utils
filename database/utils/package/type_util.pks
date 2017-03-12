CREATE OR REPLACE PACKAGE type_util IS
   /*
   * Copyright 2011-2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
   *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *     http://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   */

   /** 
   * collection type utility package
   *
   * @headcom
   */
   
   /**
   * Removes duplicate objects.
   *
   * @param in_t_obj objects to deduplicate
   * @returns deduplicated table of objects
   */
   FUNCTION dedup(in_t_obj IN t_obj_type) RETURN t_obj_type;

   /**
   * Removes duplicate columns.
   *
   * @param in_t_col columns to deduplicate
   * @returns deduplicated table of columns
   */
   FUNCTION dedup(in_t_col IN t_col_type) RETURN t_col_type;

   /**
   * Removes duplicate column lineage.
   *
   * @param in_t_col_lineage column lineage to deduplicate
   * @returns deduplicated table of column lineage
   */
   FUNCTION dedup(in_t_col_lineage IN t_col_lineage_type) RETURN t_col_lineage_type;
      
END type_util;
/
