# Define the Configuration
docpadConfig = {
    templateData:
        site:
            title: "My Website"
			
	collections:
        pages: ->
            @getCollection("html").findAllLive({isPage:true})
			
	plugins:
		ghpages:
			deployRemote: 'target'
			deployBranch: 'master'
}

# Export the Configuration
module.exports = docpadConfig