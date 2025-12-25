var GetURL = function() {};

GetURL.prototype = {
    run: function(arguments) {
        arguments.completionFunction({
            "URL": document.URL,
            "title": document.title
        });
    },
    
    finalize: function(arguments) {
        // Required method
    }
};

var ExtensionPreprocessingJS = new GetURL();
