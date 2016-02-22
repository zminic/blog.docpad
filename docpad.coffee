# Define the Configuration
docpadConfig = 
    
	templateData:
		site:
			url: "http://therealmofcode.com"
			title: "The realm of code"
			keywords: "blog, coding, development, web, technology, IT"
			description: "Personal blog about coding and web technologies - Zeljko Minic"
			
		getPreparedTitle: ->
            # if we have a document title, then we should use that and suffix the site's title onto it
            if @document.title
                "#{@document.title} | #{@site.title}"
            # if our document does not have its own title, then we should just use the site's title
            else
                @site.title
				
		getPreparedDescription: ->
            # if we have a document description, then we should use that, otherwise use the site's description
            @document.description or @site.description
			
		getPreparedKeywords: ->
            # Merge the document keywords with the site keywords
            @site.keywords.concat(@document.keywords or @document.tags or []).join(', ')

	collections:
		pages: -> @getCollection("html").findAllLive({
      isPage:true
      isPagedAuto:
        $ne: true
    },[{order:1}])
		posts: -> @getCollection("html").findAllLive({
      relativeOutDirPath:
        $like: 'posts'
      isPagedAuto:
        $ne: true
    }, [{date: -1}])

	plugins:
		ghpages:
			deployRemote: 'target'
			deployBranch: 'master'
		moment:
			formats: [
			  {raw: 'date', format: 'MMMM Do YYYY', formatted: 'humanDate'}
			  {raw: 'date', format: 'YYYY-MM-DD', formatted: 'computerDate'}
			]
		rss:
			default:
				collection: 'posts'
		stylus:
			environments:
				development:
					stylusOptions:
						compress: false
					
				
	environments:
		static:
			# exclude sourcemap files in production
			ignoreCustomPatterns: /.*\.map$/

# Export the Configuration
module.exports = docpadConfig