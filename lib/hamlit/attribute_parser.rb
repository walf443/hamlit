require 'hamlit/ruby_expression'

module Hamlit
  class AttributeParser
    class ParseSkip < StandardError
    end

    def self.parse(text)
      self.new.parse(text)
    end

    def parse(text)
      exp = wrap_bracket(text)
      return if RubyExpression.syntax_error?(exp)

      hash = {}
      tokens = Ripper.lex(exp)[1..-2] || []
      each_attr(tokens) do |attr_tokens|
        key = parse_key!(attr_tokens)
        hash[key] = attr_tokens.map(&:last).join.strip
      end
      hash
    rescue ParseSkip
      nil
    end

    private

    def wrap_bracket(text)
      text = text.strip
      return text if text[0] == '{'.freeze
      '{' << text << '}'.freeze
    end

    def parse_key!(tokens)
      _, type, str = tokens.shift
      case type
      when :on_sp
        parse_key!(tokens)
      when :on_label
        str.tr(':'.freeze, ''.freeze)
      when :on_symbeg
        _, _, key = tokens.shift
        assert_type!(tokens.shift, :on_tstring_end) if str != ':'.freeze
        skip_until_hash_rocket!(tokens)
        key
      when :on_tstring_beg
        _, _, key = tokens.shift
        next_token = tokens.shift
        unless next_token[1] == :on_label_end
          assert_type!(next_token, :on_tstring_end)
          skip_until_hash_rocket!(tokens)
        end
        key
      else
        raise ParseSkip
      end
    end

    def assert_type!(token, type)
      raise ParseSkip if token[1] != type
    end

    def skip_until_hash_rocket!(tokens)
      until tokens.empty?
        _, type, str = tokens.shift
        break if type == :on_op && str == '=>'.freeze
      end
    end

    def each_attr(tokens)
      attr_tokens = []
      array_open  = 0
      brace_open  = 0
      paren_open  = 0

      tokens.each do |token|
        (row, col), type, str = token
        case type
        when :on_comma
          if array_open == 0 && brace_open == 0 && paren_open == 0
            yield(attr_tokens)
            attr_tokens = []
            next
          end
        when :on_lbracket
          array_open += 1
        when :on_rbracket
          array_open -= 1
        when :on_lbrace
          brace_open += 1
        when :on_rbrace
          brace_open -= 1
        when :on_lparen
          paren_open += 1
        when :on_rparen
          paren_open -= 1
        when :on_sp
          next if attr_tokens.empty?
        end

        attr_tokens << token
      end
      yield(attr_tokens) unless attr_tokens.empty?
    end
  end
end
