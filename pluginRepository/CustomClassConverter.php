<?php
/**
 * Converts data from incoming packets with explicit types to custom classes.
 * If the vclass is not found, the object is unmodified.
 * Sets the explicit type marker in the data of the outgoing packets.
 * If the explicit type marker is already set in an outgoing object, the value is left as is.
 * This works for nested objects.
 * This is to support services and plugins setting the explicit type themselves.
 *
 * @author Ariel Sommeria-Klein
 */
class CustomClassConverter {

     /**
     * paths to folders containing custom classes(relative or absolute)
     * @var array of paths
     */
    public $customClassFolderPaths;

    const MAX_RECURSION_DEPTH = 10;

    public function  __construct() {
        $this->customClassFolderPaths = array(AMFPHP_ROOTPATH . "/services/vo/");
        $hookManager = HookManager::getInstance();
        $hookManager->addHook(Gateway::HOOK_PACKET_REQUEST_DESERIALIZED, array($this, "packetRequestDeserializedHandler"));
        $hookManager->addHook(Gateway::HOOK_PACKET_RESPONSE_DESERIALIZED, array($this, "packetResponseDeserializedHandler"));
    }


    /**
     * if the object or any of its sub-objects contain an explicit type marker, this method attempts to convert it to its typed counterpart
     * if the typed class is already available, then simply creates a new instance of it. If not,
     * attempts to load the file from the available service folders.
     * If then the class is still not available, the object is not converted
     * note: This is not a recursive function. Rather the recusrion is handled by AMFUtil::applyFunctionToContainedObjects.
     * must be public so that AMFUtil::applyFunctionToContainedObjects can call it
     * @param $obj it's either an object or an array
     * @return Object
     */
    public function convertToTyped($obj){
        if(!is_object($obj)){
            return $obj;
        }
        $explicitTypeField = AMFConstants::FIELD_EXPLICIT_TYPE;
        if(isset($obj->$explicitTypeField)){
            $customClassName = $obj->$explicitTypeField;
            if(!class_exists($customClassName)){
                foreach($this->customClassFolderPaths as $folderPath){
                    $customClassPath = $folderPath . "/" . $customClassName . ".php";
                    if(file_exists($customClassPath)){
                        require_once $customClassPath;
                        break;
                    }
                }
            }
            if(class_exists($customClassName)){
                //class is available. Use it!
                $typedObj =  new $customClassName();
                foreach($obj as $key => $data) { // loop over each element to copy it into typed object
                    if($key != $explicitTypeField){
                        $typedObj->$key = $data;
                    }
                }
                return $typedObj;

            }
        }

        return $obj;

     }

    /**
     * converts untyped objects to their typed counterparts. Loads the class if necessary
     * @param packet $requestPacket
     * @return packet
     */
    public function packetRequestDeserializedHandler(AMFPacket $requestPacket){
        $requestPacket = AMFUtil::applyFunctionToContainedObjects($requestPacket, array($this, "convertToTyped"), 0, self::MAX_RECURSION_DEPTH);
        return array($requestPacket);

    }

    /**
     * sets the the explicit type marker on the object and its sub-objects. This is only done if it not already set, as in some cases
     * the service class might want to do this manually.
     * note: This is not a recursive function. Rather the recusrion is handled by AMFUtil::applyFunctionToContainedObjects.
     * must be public so that AMFUtil::applyFunctionToContainedObjects can call it
     * 
     * @param stdClass $obj
     * @return stdClass
     */
    public function markExplicitType($obj){
        if(!is_object($obj)){
            return $obj;
        }
        $explicitTypeField = AMFConstants::FIELD_EXPLICIT_TYPE;
        $className = get_class ($obj);
        if($className != "stdClass" && !isset($obj->$explicitTypeField)){
            $obj->$explicitTypeField = $className;
        }
        return $obj;
    }

    /**
     * looks at the outgoing packet and sets the explicit type field so that the serializer sends it properly
     * @param packet $responsePacket
     * @return <array>
     */
    public function packetResponseDeserializedHandler(AMFPacket $responsePacket){
        $responsePacket = AMFUtil::applyFunctionToContainedObjects($responsePacket, array($this, "markExplicitType"), 0, self::MAX_RECURSION_DEPTH);
        return array($responsePacket);

    }

}
?>