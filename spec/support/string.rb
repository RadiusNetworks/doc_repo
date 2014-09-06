unless String.new.respond_to? :strip_heredoc
  String.instance_eval do # self is set to String
    define_method(:strip_heredoc) do # self is still String
      leading_space = scan(/^[ \t]*(?=\S)/).min
      indent = leading_space ? leading_space.size : 0
      gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end
