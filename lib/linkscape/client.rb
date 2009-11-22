module Linkscape
  class Client
    def initialize(*args)
      options = Hash === args.last ? args.pop : {}
      @accessID = args.first ? args.shift : (options[:id] || options[:ID] || options[:accessID])
      @secretKey = args.first ? args.shift : (options[:secret] || options[:secretKey] || options[:key])
      
      @options = {
        :apiHost => 'lsapi.seomoz.com',
        :apiRoot => 'linkscape',
        :accessID => @accessID,
        :secretKey => @secretKey
      }.merge(options)
      
    end


    def mozRank(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]

      raise MissingArgument, "mozRank requires a url." unless url

      options[:url] = url
      options[:api] = 'mozrank'

      Linkscape::Request.run(@options.merge(options))
    end


    def urlMetrics(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]

      raise MissingArgument, "urlMetrics requires a url." unless url

      options[:url] = url
      options[:api] = 'url-metrics'

      options[:query] = {
        'Cols' => translateBitfield(options[:cols], options[:columns], options[:fields], :type => :url)
      }
      
      raise MissingArgument, "urlMetrics requires a list of columns to return." unless options[:query]['Cols'].nonzero?
      
      Linkscape::Request.run(@options.merge(options))
    end


    def topLinks(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]
      whichSet = (args.first ? args.shift : options[:set]).to_sym
      
      raise MissingArgument, "topLinks requires a set (:page, :subdomain, :domain) and a url." unless whichSet and url
      
      options[:url] = url

      options[:api] = {
        :page => 'page-linklist',
        :subdomain => 'subdomain-linklist',
        :domain => 'domain-linklist',
      }[whichSet]
      
      raise InvalidArgument, "topLinks set must be one of :page, :subdomain, :domain" unless options[:api]
      
      options[:query] = {
        'SourceCols' => translateBitfield(options[:sourcecols], options[:sourcecolumns], options[:urlcols], :type => :url),
        'TargetCols' => translateBitfield(options[:targetcols], options[:targetcolumns], options[:urlcols], :type => :url),
        'LinkCols' => translateBitfield(options[:cols], options[:columns], options[:linkcols], :type => :link),
      }

      raise MissingArgument, "topLinks requires a list of columns for Source, Target, and Link." unless options[:query]['SourceCols'].nonzero? and options[:query]['TargetCols'].nonzero? and options[:query]['LinkCols'].nonzero?
      
      Linkscape::Request.run(@options.merge(options))
    end


    def allLinks(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]
      scope = args.length > 2 ? "#{args.shift}_to_#{args.shift}" : (args.first ? args.shift : options[:scope])
      sortOrder = (args.first ? args.shift : (options[:sort] || options[:sortOrder])).to_sym
      filters = args.first ? args.shift : (options[:filters] || options[:filter])

      raise MissingArgument, "allLinks requires a scope ([page, domain] to [page, subdomain, domain]) and a url." unless scope and url
      raise InvalidArgument, "allLinks scope must be valid ([page, domain] to [page, subdomain, domain])" unless scope =~ /^(page|domain)_to_(page|subdomain|domain)$/
      raise InvalidArgument, "allLinks sort order must be valid (domain_authority, page_strength, domains_linking_page, domains_linking_domain)" unless [:domain_authority, :page_strength, :domains_linking_page, :domains_linking_domain].include? sortOrder

      if String === filters
        filters = filters.downcase.split(/[,\s\+]+/).sort.collect(&:to_sym)
      elsif Hash === filters
        filters = filters.keys.collect{|k|k.to_s.downcase}.sort.collect(&:to_sym)
      elsif Array === filters
        filters = filters.collect{|k|k.to_s.downcase}.sort.collect(&:to_sym)
      elsif Symbol === filters
        filters = [filters]
      else
        raise InvalidArgument, "allLinks filters must be a string, hash, or array"
      end
      raise InvalidArgument, "allLinks filters must be from the set (:internal, :external, :redir301, :follow, :nofollow)" unless (filters - [:internal, :external, :redir301, :follow, :nofollow]).empty?

      options[:url] = url
      options[:api] = 'links'

      options[:query] = {
        'SourceCols' => translateBitfield(options[:sourcecols], options[:sourcecolumns], options[:urlcols], :type => :url),
        'TargetCols' => translateBitfield(options[:targetcols], options[:targetcolumns], options[:urlcols], :type => :url),
        'LinkCols' => translateBitfield(options[:cols], options[:columns], options[:linkcols], :type => :link),
        'Scope' => scope,
        'Filter' => filters.join('+'),
        'Sort' => sortOrder.to_s,
      }

      raise MissingArgument, "allLinks requires a list of columns for Source, Target, and Link." unless options[:query]['SourceCols'].nonzero? and options[:query]['TargetCols'].nonzero? and options[:query]['LinkCols'].nonzero?
      
      Linkscape::Request.run(@options.merge(options))
    end

    
    def topPages(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]
      whichSet = (args.first ? args.shift : options[:set]).to_sym
      
      raise MissingArgument, "topLinks requires a set (:page, :subdomain, :domain) and a url." unless whichSet and url
      
      options[:url] = url
      options[:api] = 'top-pages'
      
      raise InvalidArgument, "topLinks set must be one of :page, :subdomain, :domain" unless options[:api]
      
      options[:query] = {
        'Cols' => translateBitfield(options[:cols], options[:columns], options[:linkcols], :type => :url),
      }

      raise MissingArgument, "topLinks requires a list of columns to return." unless options[:query]['Cols'].nonzero?
      
      Linkscape::Request.run(@options.merge(options))
    end


    def anchorMetrics(*args)
      options = Hash === args.last ? args.pop.symbolize_keys : {}
      url = args.first ? args.shift : options[:url]
      scope = args.first ? args.shift : options[:scope]
      filters = args.first ? args.shift : (options[:filters] || options[:filter])

      scope = "page_to_#{scope}" unless scope =~ /^page_to_/

      raise MissingArgument, "anchorMetrics requires a scope (page to [page, subdomain, domain]) and a url." unless scope and url
      raise InvalidArgument, "anchorMetrics scope must be valid ([page, domain] to [page, subdomain, domain])" unless scope =~ /^page_to_(page|subdomain|domain)$/

      if String === filters
        filters = filters.downcase.split(/[,\s\+]+/).sort.collect(&:to_sym)
      elsif Hash === filters
        filters = filters.keys.collect{|k|k.to_s.downcase}.sort.collect(&:to_sym)
      elsif Array === filters
        filters = filters.collect{|k|k.to_s.downcase}.sort.collect(&:to_sym)
      elsif Symbol === filters
        filters = [filters]
      else
        raise InvalidArgument, "anchorMetrics filters must be a string, hash, or array"
      end
      raise InvalidArgument, "anchorMetrics filters must be from the set (:internal, :external, :redir301, :follow, :nofollow)" unless (filters - [:internal, :external, :redir301, :follow, :nofollow]).empty?

      options[:url] = url
      options[:api] = 'anchor-text'

      options[:query] = {
        'Cols' => translateBitfield(options[:cols], options[:columns], options[:linkcols], :type => :anchors),
        'Scope' => scope,
        'Filter' => filters.join('+'),
      }

      raise MissingArgument, "anchorMetrics requires a list of columns to return." unless options[:query]['Cols'].nonzero?
      
      Linkscape::Request.run(@options.merge(options))
    end




    def inspect
      %Q[#<#{self.class}:#{"0x%x" % self.object_id} api="#{@options[:apiHost]}/#{@options[:apiRoot]}" accessID="#{@options[:accessID]}">]
    end
    
    private
    
    def translateBitfield *columns
      options = Hash === columns.last ? columns.pop : {}

      columns.flatten!
      columns.compact!

      bits = columns.inject(0) do |bitfield, key|
        requestBit = 
          if options[:type] == :url
            Linkscape::Constants::URLMetrics::RequestBits[key]
          elsif options[:type] == :link
            Linkscape::Constants::LinkMetrics::RequestBits[key]
          elsif options[:type] == :anchors
            Linkscape::Constants::AnchorMetrics::RequestBits[key]
          else
            Linkscape::Constants::URLMetrics::RequestBits[key] || Linkscape::Constants::LinkMetrics::RequestBits[key]
          end
        raise InvalidArgument, "Unknown #{options[:type]} flag '#{key.inspect}'".gsub(/  +/, ' ') unless requestBit
        bitfield |= requestBit[:flag]
      end
      
      bits
    end
    
  end
end