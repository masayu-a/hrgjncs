# frozen_string_literal: true

require "csv"

# =======================
# Utilities
# =======================

class String
  # カタカナ → ひらがな
  def to_hira
    tr("ァ-ン", "ぁ-ん")
  end
end

def sorted_chars(str)
  str.each_char.sort.join
end

def uniq_join(arr, sep = ":")
  arr.sort.uniq.join(sep)
end

# =======================
# Exclusion settings
# =======================
# 「集合」はこのスクリプト内では *ソート済み文字列* がキーなので、
# 除外したい表記（例: "ぽこ"）も sorted_chars して登録してください。
#
# 例:
# EXCLUDE_BIGRAM_RAW  = %w[ぽこ ぴよ]   # raw で書いてOK（内部でソート化）
# EXCLUDE_TRIGRAM_RAW = %w[あいう かきく]
#
EXCLUDE_BIGRAM_RAW  = %w[ばこ ぱこ].freeze
EXCLUDE_TRIGRAM_RAW = %w[にんず にせん].freeze

# ★修正：to_h は [key,value] の配列が必要なので、true を値にする
EXCLUDE_BIGRAM_KEYS  = EXCLUDE_BIGRAM_RAW.map { |s| [sorted_chars(s), true] }.to_h.freeze
EXCLUDE_TRIGRAM_KEYS = EXCLUDE_TRIGRAM_RAW.map { |s| [sorted_chars(s), true] }.to_h.freeze

def excluded_key?(len, key)
  case len
  when 2 then EXCLUDE_BIGRAM_KEYS.key?(key)
  when 3 then EXCLUDE_TRIGRAM_KEYS.key?(key)
  else false
  end
end

# =======================
# Column indices (0-based)
# =======================
COL = {
  class_no: 7,      # 分類番号
  heading: 11,      # 見出し
  headword: 12,     # 見出し本体
  reading: 13,      # 読み
  write_score: 16   # 書く
}.freeze

# =======================
# Filters / Normalization
# =======================
SMALL_HIRA_OR_ETC = /[ぁぃぅぇぉ・を]/
FULLWIDTH_AZ_ONLY = /\A[Ａ-Ｚ]+\z/
KATAKANA_ONLY     = /\A[ァ-ヶー]+\z/

def normalize_reading!(tokens)
  headword = tokens[COL[:headword]]
  reading  = tokens[COL[:reading]]

  # 長音「ー」処理：
  # 見出し本体に「ー」があるのに読み側に「ー」がない場合、
  # 見出し本体がカタカナのみなら、それをひらがなにして読みとして採用。
  if headword.include?("ー") && !reading.include?("ー")
    return false unless headword.match?(KATAKANA_ONLY)

    tokens[COL[:reading]] = headword.to_hira
  end

  true
end

def skip_row?(tokens)
  reading  = tokens[COL[:reading]]
  class_no = tokens[COL[:class_no]]
  heading  = tokens[COL[:heading]]
  headword = tokens[COL[:headword]]

  return true if reading.length > 3
  return true if reading.match?(SMALL_HIRA_OR_ETC)
  return true unless class_no.start_with?("1")      # 名詞のみ 全ての単語を対象するときは、ここをコメントアウト
  return true if heading.include?("−")
  return true if headword.include?("−")
  return true if headword.match?(FULLWIDTH_AZ_ONLY) # 英語のみを削除

  false
end

# =======================
# Accumulators (auto-array hashes)
# =======================
# bicount: 1文字 => { base:, count:, candidates:, bigram_keys:, bigram_words: }
bicount   = {}

unigram2H = Hash.new { |h, k| h[k] = [] } # 1文字 => [2文字集合キー...]
unigram3H = Hash.new { |h, k| h[k] = [] } # 1文字 => [3文字集合キー...]
bigramH   = Hash.new { |h, k| h[k] = [] } # 2文字集合キー => [見出し...]
trigramH  = Hash.new { |h, k| h[k] = [] } # 3文字集合キー => [見出し...]

def add_ngram!(ngram_hash, unigram_hash, key, heading)
  ngram_hash[key] << heading
  key.each_char { |c| unigram_hash[c] << key }
end

# =======================
# Read CSV & Build
# =======================
CSV.foreach("bunruidb-fam.csv", headers: false) do |row|
  tokens = row

  next if skip_row?(tokens)
  next unless normalize_reading!(tokens)
  next unless tokens[COL[:write_score]].to_f > 0 # 「書く」

  reading = tokens[COL[:reading]]
  heading = tokens[COL[:heading]]
  key     = sorted_chars(reading)

  # ★ 指定した2文字集合・3文字集合を除外
  next if excluded_key?(reading.length, key)

  case reading.length
  when 3
    add_ngram!(trigramH, unigram3H, key, heading)
  when 2
    add_ngram!(bigramH, unigram2H, key, heading)
  end
end

# =======================
# Safety purge (optional but recommended)
# 取りこぼしがあっても完全に消えるように、集計後にも削除
# =======================
def purge_keys!(ngramH, unigramH, bad_keys)
  bad_keys.each_key do |k|
    ngramH.delete(k)
    unigramH.each_value { |arr| arr.delete(k) }
  end
  unigramH.delete_if { |_ch, arr| arr.empty? }
end

purge_keys!(bigramH, unigram2H, EXCLUDE_BIGRAM_KEYS)
purge_keys!(trigramH, unigram3H, EXCLUDE_TRIGRAM_KEYS)

# =======================
# Writers
# =======================
File.open("2gram.txt", "w") do |fh|
  fh.puts "２文字集合\t可能な２文字単語"
  bigramH.sort.each { |k, v| fh.puts "#{k}\t#{uniq_join(v)}" }
end

File.open("3gram.txt", "w") do |fh|
  fh.puts "３文字集合\t可能な３文字単語"
  trigramH.sort.each { |k, v| fh.puts "#{k}\t#{uniq_join(v)}" }
end

File.open("1_2chars.txt", "w") do |fh|
  fh.puts "１文字\t待ち候補文字の数\t待ち候補文字\t成立する２文字集合\t成立する２文字単語"

  unigram2H.sort.each do |char, keys|
    uniq_keys = keys.sort.uniq

    wait_chars   = []
    bigram_words = []

    uniq_keys.each do |k|
      other = k.sub(char, "")
      wait_chars << other
      bigram_words << uniq_join(bigramH[k])
    end

    entry = {
      base: char,
      count: uniq_keys.length,
      candidates: wait_chars,
      bigram_keys: uniq_keys,
      bigram_words: bigram_words
    }
    bicount[char] = entry

    fh.puts [
      char,
      entry[:count],
      entry[:candidates].join(" "),
      entry[:bigram_keys].join(" "),
      entry[:bigram_words].join(" ")
    ].join("\t")
  end
end

File.open("1_3chars.txt", "w") do |fh|
  fh.puts "１文字\t成立する３文字単語数\t成立する３文字集合\t成立する３文字単語"

  unigram3H.sort.each do |char, keys|
    uniq_keys = keys.sort.uniq
    trigram_words = uniq_keys.map { |k| uniq_join(trigramH[k]) }

    fh.puts [
      char,
      uniq_keys.length,
      uniq_keys.join(" "),
      trigram_words.join(" ")
    ].join("\t")
  end
end

File.open("2_3chars.txt", "w") do |fh|
  fh.puts "成立した２文字集合\t成立した２文字単語\t待ち候補文字数\t待ち候補文字\t成立する３文字集合\t成立する３文字単語"

  bigramH.sort.each do |k, words2|
    targets = []
    target_words = []

    trigramH.sort.each do |k3, words3|
      if k3.include?(k[0]) && k3.include?(k[1])
        targets << k3
        target_words << uniq_join(words3)
      end
    end

    next if targets.empty?

    wait_chars = targets.map do |t|
      rest = t.sub(k[0], "")
      rest.sub(k[1], "")
    end

    fh.puts [
      k,
      uniq_join(words2),
      wait_chars.length,
      wait_chars.join(" "),
      targets.join(" "),
      target_words.join(" ")
    ].join("\t")
  end
end

# =======================
# nobetan (4文字集合の生成)
# =======================
def bicount_fields(entry, delete_chars: [])
  return "" if entry.nil?

  candidates = entry[:candidates].dup
  keys       = entry[:bigram_keys].dup
  words      = entry[:bigram_words].dup
  count      = entry[:count]

  delete_chars.each do |dc|
    while (i = candidates.index(dc))
      candidates.delete_at(i)
      keys.delete_at(i)
      words.delete_at(i)
      count -= 1
    end
  end

  [
    entry[:base],
    count,
    candidates.join(" "),
    keys.join(" "),
    words.join(" ")
  ].join("\t")
end

tricount = 0

File.open("nobetan.txt", "w") do |fh|
  fh.puts "４文字集合\t成立した３文字集合\t成立した３文字単語\t残り１文字\t残り１文字に対する待ち候補文字数\t残り１文字に対する待ち候補文字\t成立する２文字集合\t成立する２文字単語"

  trigram_keys = trigramH.keys.sort

  trigram_keys.each do |k|
    trigram_keys.each do |k2|
      next if k == k2

      # 重複抑制条件（キーはソート済み文字列の前提）
      next unless (k[0] <= k2[0] && k[1] <= k2[1] && k[2] <= k2[2])

      knew  = k.dup
      match = +""
      k2new = +""

      k2.each_char do |ch|
        if knew.include?(ch)
          knew.sub!(ch, "")
          match << ch
        else
          k2new << ch
        end
      end

      next unless knew.length == 1 && k2new.length == 1

      chars4 = sorted_chars(knew + match + k2new)

      counts = chars4.each_char.tally
      unique_len = counts.length

      words_k  = uniq_join(trigramH[k])
      words_k2 = uniq_join(trigramH[k2])

      if unique_len == 4
        fh.puts "#{chars4}\t#{k}\t#{words_k}\t#{bicount_fields(bicount[k2new])}"
        fh.puts "#{chars4}\t#{k2}\t#{words_k2}\t#{bicount_fields(bicount[knew])}"

      elsif unique_len == 3
        tricount += 1
        delete_char = counts.find { |_c, n| n == 2 }&.first

        fh.puts "#{chars4}\t#{k}\t#{words_k}\t#{bicount_fields(bicount[k2new], delete_chars: [delete_char].compact)}"
        fh.puts "#{chars4}\t#{k2}\t#{words_k2}\t#{bicount_fields(bicount[knew], delete_chars: [delete_char].compact)}"

      else
        # 2個重複（例: ううふふ / かかくく など）を想定
        delete_chars = counts.select { |_c, n| n == 2 }.keys

        fh.puts "#{chars4}\t#{k}\t#{words_k}\t#{bicount_fields(bicount[k2new], delete_chars: delete_chars)}"
        fh.puts "#{chars4}\t#{k2}\t#{words_k2}\t#{bicount_fields(bicount[knew], delete_chars: delete_chars)}"
      end
    end
  end
end

STDERR.puts "1個重複数\t#{tricount}"
