  declare function local:analyze-col($col as element()) as element()* {
     let $tableAlias := $col/ancestor::QUERY[1]//FROM_ITEM//TABLE_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                        and text() = $col/TABLE_ALIAS/text()]
     let $tableAliasTable := if ($tableAlias) then (
                                $tableAlias/preceding::TABLE[1]
                             ) else (
                             )
     let $queryAlias := $col/ancestor::QUERY[1]//FROM_ITEM//QUERY_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                        and text() = $col/TABLE_ALIAS/text()]
     let $column := $col/COLUMN
     let $ret := if ($queryAlias) then (
                    for $rcol in $col/ancestor::QUERY//WITH_ITEM[QUERY_ALIAS/text() = $queryAlias/text()]
                                 //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                or COLUMN/text = $column/text()]
                    let $rret := if ($rcol) then (
                                    local:analyze-col($rcol)
                                 ) else (
                                 )
                    return $rret
                 ) else (
                    let $tables := if ($tableAliasTable) then (
                                      $tableAliasTable
                                   ) else (
                                      for $tab in $col/ancestor::QUERY[1]//FROM_ITEM//*[self::TABLE or self::QUERY_ALIAS]
                                      return $tab
                                   )
                    for $tab in $tables
                    return
                       typeswitch($tab)
                       case element(QUERY_ALIAS)
                          return
                             let $rcol := $col/ancestor::QUERY//WITH_ITEM[QUERY_ALIAS/text() = $tab/text()]
                                          //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                         or COLUMN/text = $column/text()]
                             let $rret := if ($rcol) then (
                                             local:analyze-col($rcol) 
                                          ) else (
                                          )
                             return $rret
                       default
                          return
                             <column>
                                <schemaName>
                                   {$tab/../SCHEMA/text()}
                                </schemaName>
                                <tableName>
                                   {$tab/text()}
                                </tableName>
                                <columnName>
                                   {$column/text()}
                                </columnName>
                             </column>
                 )
     return $ret
  };
  
  for $col in //SELECT_LIST_ITEM[not (ancestor::FROM) and not (ancestor::WITH)][1]//COLUMN_REF
  let $res := local:analyze-col($col)
  return $res
(: Stylus Studio meta-information - (c) 2004-2009. Progress Software Corporation. All rights reserved.

<metaInformation>
	<scenarios>
		<scenario default="yes" name="source_view" userelativepaths="yes" externalpreview="no" useresolver="yes" url="source_view.xml" outputurl="" processortype="datadirect" tcpport="0" profilemode="0" profiledepth="" profilelength="" urlprofilexml=""
		          commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="-1996891896" user="" password="" validateoutput="no"
		          validator="internal" customvalidator="">
			<advancedProperties name="CollectionURIResolver" value=""/>
			<advancedProperties name="ModuleURIResolver" value=""/>
			<advancedProperties name="DocumentURIResolver" value=""/>
		</scenario>
		<scenario default="no" name="plscope_tab_usage" userelativepaths="yes" externalpreview="no" useresolver="yes" url="plscope_tab_usage.xml" outputurl="" processortype="datadirect" tcpport="0" profilemode="0" profiledepth="" profilelength=""
		          urlprofilexml="" commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="0" user="" password="" validateoutput="no"
		          validator="internal" customvalidator="">
			<advancedProperties name="CollectionURIResolver" value=""/>
			<advancedProperties name="ModuleURIResolver" value=""/>
			<advancedProperties name="DocumentURIResolver" value=""/>
		</scenario>
	</scenarios>
	<MapperMetaTag>
		<MapperInfo srcSchemaPathIsRelative="yes" srcSchemaInterpretAsXML="no" destSchemaPath="" destSchemaRoot="" destSchemaPathIsRelative="yes" destSchemaInterpretAsXML="no">
			<SourceSchema srcSchemaPath="plscope_tab_usage.xml" srcSchemaRoot="QUERY" AssociatedInstance="" loaderFunction="document" loaderFunctionUsesURI="no"/>
		</MapperInfo>
		<MapperBlockPosition>
			<template name="xquery_body">
				<block path="flwr" x="460" y="18"/>
			</template>
		</MapperBlockPosition>
		<TemplateContext></TemplateContext>
		<MapperFilter side="source"></MapperFilter>
	</MapperMetaTag>
</metaInformation>
:)