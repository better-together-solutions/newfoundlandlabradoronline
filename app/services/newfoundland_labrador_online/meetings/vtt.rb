# frozen_string_literal: true

require 'cgi'

module NewfoundlandLabradorOnline
  module Meetings
    # Turns WebVTT captions into cues of start_ms, end_ms and text. YouTube's automatic captions roll: each cue repeats
    # the previous line and adds a new one, with word timing tags inside the text. Tags are removed and a line already
    # shown by the previous cue is dropped, so every line of speech appears once.
    module Vtt
      TIMING = /(?<start>(?:\d+:)?\d{1,2}:\d{2}\.\d{3})\s+-->\s+(?<end>(?:\d+:)?\d{1,2}:\d{2}\.\d{3})/

      module_function

      def parse(text)
        previous = []
        blocks(text).filter_map do |start_ms, end_ms, lines|
          fresh = lines - previous
          previous = lines if lines.any?
          next if fresh.empty?

          { 'start_ms' => start_ms, 'end_ms' => end_ms, 'text' => fresh.join(' ') }
        end
      end

      def plain_text(cues) = cues.map { |cue| cue['text'] }.join("\n")

      def blocks(text)
        text.to_s.gsub("\r\n", "\n").split(/\n{2,}/).filter_map do |block|
          lines = block.split("\n")
          index = lines.index { |line| line.match?(TIMING) }
          next unless index

          timing = lines[index].match(TIMING)
          [millis(timing[:start]), millis(timing[:end]), clean(lines[(index + 1)..])]
        end
      end

      def clean(lines)
        lines.map { |line| CGI.unescapeHTML(line.gsub(/<[^>]*>/, '')).squish }.compact_blank
      end

      def millis(stamp)
        parts = stamp.split(':').map(&:to_f)
        parts.unshift(0.0) while parts.length < 3
        (((parts[0] * 3600) + (parts[1] * 60) + parts[2]) * 1000).round
      end
    end
  end
end
