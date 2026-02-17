// Workspace: hush

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1196.
//
        vkCmdBeginRenderingKHR = cast(PFN_vkCmdBeginRenderingKHR) vkGetDeviceProcAddr(vk_device, "vkCmdBeginRenderingKHR");
        loaded_all_pfns &= vkCmdBeginRenderingKHR != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1197.
//
        vkCmdEndRenderingKHR = cast(PFN_vkCmdEndRenderingKHR) vkGetDeviceProcAddr(vk_device, "vkCmdEndRenderingKHR");
        loaded_all_pfns &= vkCmdEndRenderingKHR != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1202.
//
        vkGetDescriptorSetLayoutSizeEXT = cast(PFN_vkGetDescriptorSetLayoutSizeEXT) vkGetDeviceProcAddr(vk_device, "vkGetDescriptorSetLayoutSizeEXT");
        loaded_all_pfns &= vkGetDescriptorSetLayoutSizeEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1203.
//
        vkGetDescriptorSetLayoutBindingOffsetEXT = cast(PFN_vkGetDescriptorSetLayoutBindingOffsetEXT) vkGetDeviceProcAddr(vk_device, "vkGetDescriptorSetLayoutBindingOffsetEXT");
        loaded_all_pfns &= vkGetDescriptorSetLayoutBindingOffsetEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1204.
//
        vkGetDescriptorSetLayoutBindingOffsetEXT = cast(PFN_vkGetDescriptorSetLayoutBindingOffsetEXT) vkGetDeviceProcAddr(vk_device, "vkGetDescriptorSetLayoutBindingOffsetEXT");
        loaded_all_pfns &= vkGetDescriptorSetLayoutBindingOffsetEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1205.
//
        vkGetDescriptorEXT = cast(PFN_vkGetDescriptorEXT) vkGetDeviceProcAddr(vk_device, "vkGetDescriptorEXT");
        loaded_all_pfns &= vkGetDescriptorEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1206.
//
        vkCmdBindDescriptorBuffersEXT = cast(PFN_vkCmdBindDescriptorBuffersEXT) vkGetDeviceProcAddr(vk_device, "vkCmdBindDescriptorBuffersEXT");
        loaded_all_pfns &= vkCmdBindDescriptorBuffersEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1207.
//
        vkCmdSetDescriptorBufferOffsetsEXT = cast(PFN_vkCmdSetDescriptorBufferOffsetsEXT) vkGetDeviceProcAddr(vk_device, "vkCmdSetDescriptorBufferOffsetsEXT");
        loaded_all_pfns &= vkCmdSetDescriptorBufferOffsetsEXT != null;

//
// #insert text. Generated from /home/ixilminiussi/Desktop/gamedev/hush/modules/sgpu/module.jai:1210.
//
        vkCmdDrawMeshTasksEXT = cast(PFN_vkCmdDrawMeshTasksEXT) vkGetDeviceProcAddr(vk_device, "vkCmdDrawMeshTasksEXT");
        loaded_all_pfns &= vkCmdDrawMeshTasksEXT != null;
