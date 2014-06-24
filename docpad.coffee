# Define the Configuration
docpadConfig = {
    templateData:
        site:
            title: "The realm of code"
			
	collections:
        pages: ->
            @getCollection("html").findAllLive({isPage:true},[{order:1}])
			
	plugins:
		ghpages:
			deployRemote: 'target'
			deployBranch: 'master'
}

# Export the Configuration
module.exports = docpadConfig