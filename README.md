# hrgjncs (version 1.0) (2026/01/01)

## Description

『分類語彙表』増補改訂版データベースの親密度情報 WLSP-Familiarity-4.0.0 を用いて
「書く」の親密度が 0.0 以上の単語（名詞：体の類）を対象として
あと１文字で単語（名詞）をなす文字集合をリスト化した

## Features

### 2gram.txt ２文字単語

- 1列目 ２文字集合
- 2列目 可能な２文字単語

### 3gram.txt ３文字単語

- 1列目 ３文字集合
- 2列目 可能な３文字単語

### 1_2chars.txt あと１文字で２文字単語になる１文字

- 1列目 １文字
- 2列目 待ち候補文字の数
- 3列目 待ち候補文字
- 4列目 成立する２文字集合
- 5列目 成立する２文字単語

![1_2chars](img/1_2chars.jpg)

### 1_3chars.txt あと２文字で３文字単語になる１文字

- 1列目 １文字
- 2列目 成立する３文字単語数
- 3列目 成立する３文字集合
- 4列目 成立する３文字単語
  
### 2_3chars.txt あと１文字で３文字単語になる２文字単語

- 1列目 成立した２文字集合
- 2列目 成立した２文字単語
- 3列目 待ち候補文字の数
- 4列目 待ち候補文字
- 5列目 成立する３文字集合
- 6列目 成立する３文字単語

![2_3chars](img/2_3chars.jpg)

### nobetan.txt ノベタン待ち可能な４文字集合（２文字共有３文字単語対）

- 1列目 ４文字集合（２文字共有３文字単語対）
- 2列目 成立した３文字集合
- 3列目 成立した３文字単語
- 4列目 残り１文字
- 5列目 残り１文字に対する待ち候補文字の数
- 6列目 残り１文字に対する待ち候補文字
- 7列目 成立する２文字集合
- 8列目 成立する２文字単語

ノベタン待ちは成立した３文字単語の取り方で２通りの待ちがある（２行に分かれている）

「あいぐだ」

![nobetan1](img/nobetan1.jpg)

「ぐあい」＋「だ」とした際の待ち

![nobetan2](img/nobetan2.jpg)

「あいだ」＋「ぐ」とした際の待ち

![nobetan2](img/nobetan3.jpg)

ノベタン待ち４文字集合で同じ１文字２回出現は 1080 パターン（３回出現を許さないようにする）

ノベタン待ち４文字集合で「ううふふ」・「かかくく」が２文字２回出現（３回出現を許さないようにする）

## Author

- 浅原正幸 (国立国語研究所)

## References 

Masayuki Asahara (2019) Word Familiarity Rate Estimation Using a Bayesian Linear Mixed Model, 
Proceedings of the First Workshop on Aggregating and Analysing Crowdsourced Annotations for NLP, pages 6-14.
https://www.aclweb.org/anthology/D19-5902.pdf

浅原正幸 (2020) Bayesian Linear Mixed Model による 単語親密度推定と位相情報付与, 『自然言語処理』, 27(1), pp.133-150, https://doi.org/10.5715/jnlp.27.133

## License

CC BY-NC-SA 3.0 https://creativecommons.org/licenses/by-nc-sa/3.0/deed.ja

## Credit

National Institute for Japanese Language and Linguistics (2026) hrgjncs (ver. 1.0)

## Contact

masayu-a@ninjal.ac.jp

## Spreadsheets

https://docs.google.com/spreadsheets/d/1Q5vElHTmU7gHQA3_iYcH2Ky4_SlNQPuT1wRxuJyWMiE/edit?usp=sharing