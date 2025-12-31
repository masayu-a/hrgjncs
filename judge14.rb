#!/usr/bin/env ruby
# frozen_string_literal: true

# 高速版（有効牌計算なし）：
# - OK判定（厳密：3×4 + 2×1 で14文字を完全使用）
# - 置換数（=最小自摸回数）= 14 - 最大保持文字数
# - 向聴数 = 置換数 - 1（和了は -1）
#
# 使い方:
#   ruby shanten14_fast_rep.rb かな14文字
#   echo かな14文字 | ruby shanten14_fast_rep.rb

def read_ngram_file(path, n)
  h = {}
  File.foreach(path, chomp: true) do |line|
    next if line.empty?
    next if line.start_with?("２文字集合", "３文字集合") # header
    key, words = line.split("\t", 2)
    next unless key && key.length == n

    list =
      if words.nil? || words.empty?
        []
      else
        words.split(/[:\s]+/).reject(&:empty?)
      end

    h[key] = list
  end
  h
end

def popcount(x)
  x.to_s(2).count("1")
end

# trigram存在の「単体」「ペア」チェック（置換数用：部分保持を許す）
def build_presence(trigram_dict, bigram_dict)
  tri_single = {}
  tri_pair = {}
  trigram_dict.each_key do |k|
    a = k[0]; b = k[1]; c = k[2]
    tri_single[a] = true
    tri_single[b] = true
    tri_single[c] = true
    tri_pair[a + b] = true
    tri_pair[a + c] = true
    tri_pair[b + c] = true
  end

  bi_single = {}
  bi_pair = {}
  bigram_dict.each_key do |k|
    a = k[0]; b = k[1]
    bi_single[a] = true
    bi_single[b] = true
    bi_pair[a + b] = true
  end

  [tri_single, tri_pair, bi_single, bi_pair]
end

# 14文字（ソート済み chars）から、
# - tri_keep_masks: trigram 1個で「保持できる位置マスク」（0〜3ビット）
# - bi_keep_masks : bigram  1個で「保持できる位置マスク」（0〜2ビット）
# を列挙する（部分保持OK）
def enumerate_keep_masks(chars, trigram_dict, bigram_dict, tri_single, tri_pair, bi_single, bi_pair)
  n = chars.length # 14
  tri_masks = {}
  bi_masks = {}

  # trigram: keep3（厳密キーがある）
  (0...(n - 2)).each do |i|
    (i + 1...(n - 1)).each do |j|
      (j + 1...n).each do |k|
        key = +""
        key << chars[i] << chars[j] << chars[k] # charsがソート済みなのでkeyもソート済み
        if trigram_dict.key?(key)
          m = (1 << i) | (1 << j) | (1 << k)
          tri_masks[m] = true
        end
      end
    end
  end

  # trigram: keep2（その2文字を含むtrigramが存在）
  (0...(n - 1)).each do |i|
    (i + 1...n).each do |j|
      pair = +""
      pair << chars[i] << chars[j] # ソート済み
      if tri_pair[pair]
        m = (1 << i) | (1 << j)
        tri_masks[m] = true
      end
    end
  end

  # trigram: keep1（その文字を含むtrigramが存在）
  (0...n).each do |i|
    tri_masks[1 << i] = true if tri_single[chars[i]]
  end

  # keep0（ダミー：全交換でtrigramを作る想定）
  tri_masks[0] = true

  # bigram: keep2（厳密キーがある）
  (0...(n - 1)).each do |i|
    (i + 1...n).each do |j|
      key = +""
      key << chars[i] << chars[j] # ソート済み
      if bigram_dict.key?(key)
        m = (1 << i) | (1 << j)
        bi_masks[m] = true
      end
    end
  end

  # bigram: keep1（その文字を含むbigramが存在）
  (0...n).each do |i|
    bi_masks[1 << i] = true if bi_single[chars[i]]
  end

  # keep0
  bi_masks[0] = true

  [tri_masks.keys, bi_masks.keys]
end

# 置換数（=最小自摸回数）を高速計算：14 - 最大保持位置数
def replacement_14(chars14_sorted, trigram_dict, bigram_dict,
                   tri_single, tri_pair, bi_single, bi_pair, cache)
  sig = chars14_sorted.join
  return cache[sig] if cache.key?(sig)

  tri_opts, bi_opts =
    enumerate_keep_masks(chars14_sorted, trigram_dict, bigram_dict, tri_single, tri_pair, bi_single, bi_pair)

  n = 14

  # dp[t][b][mask] reachable
  dp = Array.new(5) { Array.new(2) { Array.new(1 << n, false) } }
  active = Array.new(5) { Array.new(2) { [] } }

  dp[0][0][0] = true
  active[0][0] << 0

  (0..4).each do |t|
    (0..1).each do |b|
      active[t][b].each do |mask|
        if t < 4
          tri_opts.each do |m|
            next unless (mask & m).zero?
            nm = mask | m
            next if dp[t + 1][b][nm]
            dp[t + 1][b][nm] = true
            active[t + 1][b] << nm
          end
        end

        if b < 1
          bi_opts.each do |m|
            next unless (mask & m).zero?
            nm = mask | m
            next if dp[t][b + 1][nm]
            dp[t][b + 1][nm] = true
            active[t][b + 1] << nm
          end
        end
      end
    end
  end

  max_keep = 0
  active[4][1].each do |mask|
    k = popcount(mask)
    max_keep = k if k > max_keep
    break if max_keep == 14
  end

  rep = 14 - max_keep
  cache[sig] = rep
  rep
end

# OK（厳密分割）の復元：3mask×4 + 2mask×1 で full を作る
def solve_ok_exact(chars14_sorted, trigram_dict, bigram_dict)
  n = 14
  full = (1 << n) - 1

  tri = [] # [mask,key]
  bi  = [] # [mask,key]

  (0...(n - 2)).each do |i|
    (i + 1...(n - 1)).each do |j|
      (j + 1...n).each do |k|
        key = +""
        key << chars14_sorted[i] << chars14_sorted[j] << chars14_sorted[k]
        next unless trigram_dict.key?(key)
        tri << [(1 << i) | (1 << j) | (1 << k), key]
      end
    end
  end

  (0...(n - 1)).each do |i|
    (i + 1...n).each do |j|
      key = +""
      key << chars14_sorted[i] << chars14_sorted[j]
      next unless bigram_dict.key?(key)
      bi << [(1 << i) | (1 << j), key]
    end
  end

  dp = Array.new(5) { Array.new(2) { Array.new(1 << n, false) } }
  prev = Array.new(5) { Array.new(2) { Array.new(1 << n) } }

  dp[0][0][0] = true

  (0..4).each do |t|
    (0..1).each do |b|
      (0..full).each do |mask|
        next unless dp[t][b][mask]

        if t < 4
          tri.each do |gmask, key|
            next unless (mask & gmask).zero?
            nm = mask | gmask
            next if dp[t + 1][b][nm]
            dp[t + 1][b][nm] = true
            prev[t + 1][b][nm] = [t, b, mask, :tri, key]
          end
        end

        if b < 1
          bi.each do |gmask, key|
            next unless (mask & gmask).zero?
            nm = mask | gmask
            next if dp[t][b + 1][nm]
            dp[t][b + 1][nm] = true
            prev[t][b + 1][nm] = [t, b, mask, :bi, key]
          end
        end
      end
    end
  end

  return nil unless dp[4][1][full]

  path = []
  t = 4
  b = 1
  mask = full
  while !(t == 0 && b == 0 && mask == 0)
    p = prev[t][b][mask]
    raise "prev missing" if p.nil?
    pt, pb, pm, type, key = p
    path << [type, key]
    t = pt
    b = pb
    mask = pm
  end
  path.reverse
end

# ---------------- main ----------------
input = (ARGV[0] || STDIN.read).to_s.strip
if input.empty?
  warn "入力が空です。14文字のかなを渡してください。"
  exit 2
end

unless input.each_char.count == 14
  puts "NG"
  exit 0
end

bigram_dict  = read_ngram_file("2gram.txt", 2)
trigram_dict = read_ngram_file("3gram.txt", 3)

tri_single, tri_pair, bi_single, bi_pair = build_presence(trigram_dict, bigram_dict)

chars14 = input.each_char.sort
cache = {} # signature -> replacement

rep = replacement_14(chars14, trigram_dict, bigram_dict, tri_single, tri_pair, bi_single, bi_pair, cache)
shanten = rep - 1

if rep == 0
  path = solve_ok_exact(chars14, trigram_dict, bigram_dict)
  if path.nil?
    puts "NG"
    puts "置換数: 0"
    puts "向聴数: -1"
    exit 0
  end

  puts "OK"
  puts "置換数: 0"
  puts "向聴数: -1"
  path.each do |type, key|
    if type == :tri
      words = trigram_dict[key] || []
      puts ["3", key, (words.empty? ? "-" : words.join(":"))].join("\t")
    else
      words = bigram_dict[key] || []
      puts ["2", key, (words.empty? ? "-" : words.join(":"))].join("\t")
    end
  end
  exit 0
end

puts "NG"
puts "置換数: #{rep}"
puts "向聴数: #{shanten}"
