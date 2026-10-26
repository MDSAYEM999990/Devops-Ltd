
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Root URL should serve React's entry point.
    if (uri === "/") {
        request.uri = "/index.html";
        return request;
    }

    
    var lastSegment = uri.substring(uri.lastIndexOf("/") + 1);

    if (lastSegment.indexOf(".") !== -1) {
        return request;
    }

   
    request.uri = "/index.html";

    return request;
}
