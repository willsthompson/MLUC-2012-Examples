xquery version "1.0-ml";
module namespace exp = "http://jonesmcclure.com/xq/exp";

import module namespace search = "http://marklogic.com/appservices/search" 
    at "/MarkLogic/appservices/search/search.xqy";
import module namespace thsr = "http://marklogic.com/xdmp/thesaurus" 
    at "/MarkLogic/thesaurus.xqy";


declare function exp:detect-year(
    $q as item()  
) as item()
{   
    typeswitch($q)    
        case element(cts:word-query) return
            let $regex-year := "((19|20)\d\d)"
            let $analyzed := 
                analyze-string($q/string(), $regex-year)
            return
                if ($analyzed/*:match)
                then
                    cts:or-query((
                        cts:query($q),
                        cts:directory-query(
                            concat("/content/",$analyzed/*:match/*:group[@nr=1]/string()
                        ))
                    ))
                else $q
        case text() return $q        
        default return 
            element {node-name($q)}{                
                $q/namespace::*,
                $q/@*,
                local:detect-year($q/node())
            }
};


declare function exp:q-add-weights(
    $q as item(),    
    $weights as element(element)+    
) as item()
{   
    typeswitch($q)    
       case element(cts:word-query) return
            element cts:or-query{
                (: original query :)
                $q,                 
                (: weighted :)        
                $weights/cts:element-word-query(
                  QName(@ns, @name), 
                  $q/cts:text/string(), 
                  $q/cts:option/string(), 
                  @weight/xs:double(.))
            }
        case text() return $q        
        default return 
            element {node-name($q)}{                
                $q/namespace::*,
                $q/@*,
                local:q-add-weights($q/node(),$weights)
            }
};

declare function exp:q-correct-spelling(
    $q as item()
) as item()
{
    typeswitch($q)
        case element(cts:word-query) return             
            let $corrected :=
                for $t in cts:tokenize($q/cts:text)
                return 
                    typeswitch($t)
                    case $t as cts:word return
                        if (spell:is-correct("/config/jmp-dictionary.xml", $t)) 
                        then $t
                        else 
                            let $suggestion := spell:suggest("/config/jmp-dictionary.xml", $t)[1]
                            return
                                if ($suggestion) then $suggestion
                                else $t
                    default return $t
            return
                element cts:word-query{                    
                    $q/@*,
                    element cts:text{ string-join($corrected,"") },
                    $q/node() except $q/cts:text
                }                        
        case text() return $q
        default return 
            element {node-name($q)}{                
                $q/namespace::*,
                $q/@*,
                local:q-correct-spelling($q/node())
            }  
};

