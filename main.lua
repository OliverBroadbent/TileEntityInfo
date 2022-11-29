ExtensionName = { -- must match name of repository
    styler = { -- object to represent an extension type, can be named anything
        type = EXTENSION_TYPE.NBT_EDITOR_STYLE, -- type of this extension
        recursive = true -- whether or not to run ExtensionName.styler:recursion() on every NBT tag in the file (more expensive)
    }
}

function ExtensionName.styler:main(root, context)
  
end

function ExtensionName.styler:recursion(root, target, context)
  
end

return ExtensionName
