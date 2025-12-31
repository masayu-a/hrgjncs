#!/usr/bin/env ruby
# frozen_string_literal: true

# 2gram.txt / 3gram.txt を読み込み、
# 与えられた14文字が「3文字単語×4 + 2文字単語×1」に分割できるか判定する。
#
# 使い方:
#   ruby judge14.rb かな14文字
#   echo かな14文字 | ruby judge14.rb
#
# 出力:
#   NG
#   あるいは
#   OK
#   3  <3文字集合キー> <候補単語(見出し)一覧>
#   ...
#   2  <2文字集合キー> <候補単語(見出し)一覧>

def sorted_chars(str)
  str.each_char.sort.join
end

def read_ngram_file(path, n)
  h = {}
  File.foreach(path, chomp: true) do |line|
    next if line.empty?
    next if line.start_with?("２文字集合", "３文字集合") # ヘッダ
    key, words = line.split("\t", 2)
    next unless key
    next unless key.length == n
    list =
      if words.nil? || words.empty?
        []
      else
        # 生成側は ":" 連結だが、念のため空白も許容
        words.split(/[:\s]+/).reject(&:empty?)
      end
    h[key] = list
  end
  h
end

def count_hash(str)
  h = Hash.new(0)
  str.each_char { |c| h[c] += 1 }
  h
end

def total_len(counts)
  counts.values.sum
end

def subset?(counts, key_counts)
  key_counts.each do |ch, kcnt|
    return false if counts[ch] < kcnt
  end
  true
end

def apply_take(counts, key_counts)
  key_counts.each { |ch, kcnt| counts[ch] -= kcnt }
end

def apply_putback(counts, key_counts)
  key_counts.each { |ch, kcnt| counts[ch] += kcnt }
end

def signature(counts)
  # 残り文字 multiset をソート文字列で表す（最大14文字なので軽い）
  counts.flat_map { |ch, cnt| [ch] * cnt }.sort.join
end

# ---------- main ----------
input = (ARGV[0] || STDIN.read).to_s.strip
if input.empty?
  warn "入力が空です。14文字のかなを渡してください。"
  exit 2
end

unless input.each_char.count == 14
  puts "NG"
  exit 0
end

bigramH  = read_ngram_file("2gram.txt", 2)
trigramH = read_ngram_file("3gram.txt", 3)

# キーの事前処理（文字カウント）
bigram_key_counts  = {}
trigram_key_counts = {}

bigramH.each_key  { |k| bigram_key_counts[k]  = count_hash(k) }
trigramH.each_key { |k| trigram_key_counts[k] = count_hash(k) }

# 文字→含むキー（分岐削減用）
tri_by_char = Hash.new { |h, k| h[k] = [] }
trigramH.each_key do |k|
  k.each_char.uniq.each { |ch| tri_by_char[ch] << k }
end

bi_by_char = Hash.new { |h, k| h[k] = [] }
bigramH.each_key do |k|
  k.each_char.uniq.each { |ch| bi_by_char[ch] << k }
end

counts0 = count_hash(input)

# メモ化（失敗状態を記録）
dead = {}

def search(counts, tri_left, bi_left, trigramH, bigramH,
           trigram_key_counts, bigram_key_counts,
           tri_by_char, bi_by_char, dead, path)

  need = tri_left * 3 + bi_left * 2
  return nil if total_len(counts) != need

  sig = [tri_left, bi_left, signature(counts)]
  return nil if dead[sig]

  if tri_left == 0 && bi_left == 0
    return path
  end

  # 次に選ぶキーを「残っている文字のうち1つ」を軸にして候補を絞る
  pivot = counts.find { |_ch, c| c > 0 }&.first

  if tri_left > 0
    candidates = pivot ? tri_by_char[pivot] : trigram_key_counts.keys
    candidates.each do |k|
      kc = trigram_key_counts[k]
      next unless subset?(counts, kc)

      apply_take(counts, kc)
      path << [:tri, k]

      res = search(counts, tri_left - 1, bi_left,
                   trigramH, bigramH,
                   trigram_key_counts, bigram_key_counts,
                   tri_by_char, bi_by_char, dead, path)
      return res if res

      path.pop
      apply_putback(counts, kc)
    end
  else
    # tri_left == 0, 2gram を1つ探す
    candidates = pivot ? bi_by_char[pivot] : bigram_key_counts.keys
    candidates.each do |k|
      kc = bigram_key_counts[k]
      next unless subset?(counts, kc)

      apply_take(counts, kc)
      path << [:bi, k]

      res = search(counts, tri_left, bi_left - 1,
                   trigramH, bigramH,
                   trigram_key_counts, bigram_key_counts,
                   tri_by_char, bi_by_char, dead, path)
      return res if res

      path.pop
      apply_putback(counts, kc)
    end
  end

  dead[sig] = true
  nil
end

solution = search(
  counts0,
  4, 1,
  trigramH, bigramH,
  trigram_key_counts, bigram_key_counts,
  tri_by_char, bi_by_char,
  dead,
  []
)

if solution.nil?
  puts "NG"
  exit 0
end

puts "OK"
solution.each do |type, key|
  if type == :tri
    words = trigramH[key] || []
    puts ["3", key, (words.empty? ? "-" : words.join(":"))].join("\t")
  else
    words = bigramH[key] || []
    puts ["2", key, (words.empty? ? "-" : words.join(":"))].join("\t")
  end
end
