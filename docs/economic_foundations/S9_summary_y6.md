# S9 Review Comparison: Tables (pre-S5b build `852fc6a`)

Ordinary condition, no player, 8 starts per land, year 6. `F` is the pooled Track A build (`110a128`) on the same founder sets. Made with `scripts/summarize_divergence.ps1` and a JSON extract of the compact measures.

## Outcomes

| Run | Environment | Cond. | Player | Towns | ok | People | Hunger days | Cold days | Deaths (h/c) | Outside food | Stone made | Bricks made | Stone/brick homes | Tick ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F | balanced | ordinary | none | 8 | 6 | 33 | 147 | 2 | 13/19 | 0.30 | 225 | 0 | 0.1 | 6.2 |
| F | fertile_valley | ordinary | none | 8 | 6 | 39 | 133 | 63 | 17/3 | 0.33 | 165 | 32 | 0.1 | 15.2 |
| F | forested | ordinary | none | 8 | 4 | 22 | 308 | 54 | 18/6 | 0.29 | 41 | 0 | 0.0 | 11.7 |
| F | marginal | ordinary | none | 8 | 3 | 22 | 141 | 122 | 9/32 | 0.25 | 0 | 0 | 0.0 | 6.1 |
| F | rocky_highland | ordinary | none | 8 | 2 | 0 | 247 | 116 | 18/1 | 0.00 | 379 | 0 | 0.8 | 6.9 |
| S9-communal | balanced | ordinary | none | 8 | 6 | 31 | 147 | 2 | 13/1 | 0.32 | 51 | 0 | 0.1 | 15.4 |
| S9-communal | fertile_valley | ordinary | none | 8 | 6 | 39 | 132 | 61 | 17/4 | 0.33 | 169 | 32 | 0.1 | 15.4 |
| S9-communal | forested | ordinary | none | 8 | 3 | 5 | 308 | 47 | 18/4 | 0.43 | 41 | 0 | 0.0 | 12.1 |
| S9-communal | marginal | ordinary | none | 8 | 3 | 22 | 141 | 122 | 9/32 | 0.25 | 0 | 0 | 0.0 | 14.5 |
| S9-communal | rocky_highland | ordinary | none | 8 | 2 | 0 | 285 | 73 | 16/0 | 0.00 | 379 | 0 | 0.8 | 7.1 |
| S9-shared | balanced | ordinary | none | 8 | 6 | 33 | 159 | 33 | 15/9 | 0.29 | 155 | 0 | 0.3 | 12.0 |
| S9-shared | fertile_valley | ordinary | none | 8 | 5 | 26 | 203 | 96 | 12/5 | 0.43 | 21 | 20 | 0.0 | 13.3 |
| S9-shared | forested | ordinary | none | 8 | 5 | 45 | 112 | 84 | 5/1 | 0.33 | 917 | 0 | 1.5 | 18.8 |
| S9-shared | marginal | ordinary | none | 8 | 3 | 15 | 170 | 188 | 12/11 | 0.40 | 0 | 0 | 0.0 | 16.0 |
| S9-shared | rocky_highland | ordinary | none | 8 | 1 | 0 | 391 | 101 | 20/0 | 0.00 | 92 | 0 | 0.0 | 7.7 |
| S9-private | balanced | ordinary | none | 8 | 6 | 27 | 629 | 8 | 7/6 | 0.36 | 55 | 0 | 0.0 | 5.9 |
| S9-private | fertile_valley | ordinary | none | 8 | 4 | 28 | 688 | 112 | 11/3 | 0.25 | 99 | 13 | 1.0 | 6.2 |
| S9-private | forested | ordinary | none | 8 | 3 | 23 | 611 | 108 | 5/2 | 0.27 | 659 | 0 | 0.5 | 5.4 |
| S9-private | marginal | ordinary | none | 8 | 2 | 12 | 659 | 154 | 9/11 | 0.30 | 0 | 0 | 0.0 | 4.7 |
| S9-private | rocky_highland | ordinary | none | 8 | 0 | 0 | 575 | 140 | 10/3 | 0.00 | 172 | 0 | 0.1 | 3.7 |
| S9-shared-commons | balanced | ordinary | none | 8 | 4 | 30 | 279 | 28 | 15/8 | 0.33 | 186 | 0 | 0.4 | 5.8 |
| S9-shared-commons | fertile_valley | ordinary | none | 8 | 4 | 50 | 461 | 175 | 16/3 | 0.29 | 411 | 28 | 0.6 | 6.7 |
| S9-shared-commons | forested | ordinary | none | 8 | 4 | 27 | 344 | 152 | 8/7 | 0.43 | 655 | 0 | 1.1 | 6.2 |
| S9-shared-commons | marginal | ordinary | none | 8 | 3 | 21 | 282 | 250 | 5/25 | 0.26 | 0 | 0 | 0.0 | 5.4 |
| S9-shared-commons | rocky_highland | ordinary | none | 8 | 1 | 0 | 324 | 89 | 19/0 | 0.00 | 73 | 0 | 0.0 | 3.2 |
| S9-private-commons | balanced | ordinary | none | 8 | 1 | 24 | 999 | 70 | 7/1 | 0.33 | 0 | 0 | 0.0 | 5.6 |
| S9-private-commons | fertile_valley | ordinary | none | 8 | 1 | 24 | 964 | 127 | 2/0 | 0.36 | 425 | 5 | 0.3 | 6.0 |
| S9-private-commons | forested | ordinary | none | 8 | 1 | 16 | 958 | 166 | 8/2 | 0.29 | 431 | 0 | 0.0 | 5.4 |
| S9-private-commons | marginal | ordinary | none | 8 | 0 | 13 | 1108 | 186 | 1/19 | 0.25 | 0 | 0 | 0.0 | 4.2 |
| S9-private-commons | rocky_highland | ordinary | none | 8 | 0 | 0 | 669 | 185 | 16/7 | 0.00 | 419 | 0 | 0.1 | 3.6 |

## Ownership, help and market

| Run | Land | Community worth | Family worth | Holding gini | Given | Granted | Help given | Short beside commons | Short beside spare | Market units | Emergency sales | Farm wealth | Woodcutter wealth | Wood in store |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S9-communal | balanced | 13052 | 18 | 0.73 | 0 | 0 | 0 | 522 | 0 | 0 | 0 | 0 | 0 | 1176 |
| S9-communal | fertile_valley | 13704 | 4 | 0.89 | 0 | 0 | 0 | 519 | 0 | 0 | 0 | 0 | 5 | 1651 |
| S9-communal | forested | 8716 | 0 | 0.0 | 0 | 0 | 1 | 769 | 0 | 0 | 0 | 0 | 25 | 525 |
| S9-communal | marginal | 5120 | 0 | 0.0 | 0 | 0 | 0 | 354 | 0 | 0 | 0 | 0 | 1 | 684 |
| S9-communal | rocky_highland | 630 | 0 | 0.0 | 0 | 0 | 0 | 675 | 0 | 0 | 0 | 4 | 0 | 35 |
| S9-shared | balanced | 7906 | 5091 | 0.78 | 72 | 0 | 0 | 562 | 0 | 0 | 0 | 84 | 2055 | 2399 |
| S9-shared | fertile_valley | 9908 | 2203 | 0.79 | 433 | 0 | 25 | 629 | 0 | 271 | 0 | 48 | 819 | 1028 |
| S9-shared | forested | 12154 | 3876 | 0.75 | 1158 | 0 | 0 | 464 | 0 | 486 | 0 | 24 | 964 | 1393 |
| S9-shared | marginal | 3519 | 579 | 0.64 | 118 | 0 | 0 | 446 | 0 | 55 | 0 | 45 | 264 | 614 |
| S9-shared | rocky_highland | 1052 | 0 | 0.0 | 0 | 0 | 0 | 780 | 0 | 0 | 0 | 126 | 572 | 417 |
| S9-private | balanced | 3264 | 7503 | 0.57 | 3427 | 0 | 862 | 595 | 215 | 58 | 4 | 631 | 1813 | 3291 |
| S9-private | fertile_valley | 2185 | 6160 | 0.6 | 2600 | 0 | 978 | 495 | 372 | 877 | 6 | 277 | 979 | 1361 |
| S9-private | forested | 4219 | 6688 | 0.53 | 1362 | 0 | 971 | 397 | 295 | 737 | 27 | 461 | 1253 | 2266 |
| S9-private | marginal | 235 | 368 | 0.5 | 925 | 0 | 295 | 594 | 189 | 250 | 0 | 184 | 229 | 796 |
| S9-private | rocky_highland | 201 | 0 | 0.0 | 198 | 0 | 90 | 408 | 247 | 280 | 0 | 698 | 1317 | 122 |
| S9-shared-commons | balanced | 9707 | 4584 | 0.58 | 213 | 1983 | 0 | 861 | 2 | 0 | 0 | 284 | 1802 | 2608 |
| S9-shared-commons | fertile_valley | 11541 | 4020 | 0.75 | 803 | 1121 | 13 | 1088 | 20 | 206 | 0 | 79 | 932 | 1820 |
| S9-shared-commons | forested | 3487 | 2494 | 0.67 | 18 | 581 | 0 | 887 | 40 | 192 | 0 | 26 | 513 | 1078 |
| S9-shared-commons | marginal | 1229 | 1537 | 0.4 | 7 | 139 | 0 | 737 | 0 | 95 | 0 | 76 | 1005 | 1558 |
| S9-shared-commons | rocky_highland | 258 | 0 | 0.0 | 0 | 101 | 0 | 618 | 0 | 0 | 0 | 848 | 1077 | 839 |
| S9-private-commons | balanced | 911 | 5945 | 0.65 | 1259 | 148 | 968 | 541 | 226 | 83 | 269 | 394 | 2872 | 2928 |
| S9-private-commons | fertile_valley | 563 | 6901 | 0.63 | 1465 | 211 | 1312 | 530 | 241 | 525 | 331 | 276 | 2807 | 3112 |
| S9-private-commons | forested | 2264 | 5414 | 0.53 | 535 | 964 | 799 | 576 | 281 | 657 | 154 | 392 | 1300 | 3684 |
| S9-private-commons | marginal | 297 | 1876 | 0.65 | 285 | 84 | 272 | 683 | 448 | 203 | 119 | 375 | 152 | 640 |
| S9-private-commons | rocky_highland | 189 | 0 | 0.0 | 115 | 116 | 171 | 544 | 208 | 120 | 63 | 358 | 920 | 125 |

## By founder set (start k = founder set k)

Y ok, . alive but not ok, x empty
| Land | Run | s0 | s1 | s2 | s3 | s4 | s5 | s6 | s7 |
|---|---|---|---|---|---|---|---|---|---|
| balanced | F | Y | x | Y | x | Y | Y | Y | Y |
| balanced | S9-communal | Y | x | Y | x | Y | Y | Y | Y |
| balanced | S9-shared | Y | x | x | Y | Y | Y | Y | Y |
| balanced | S9-private | Y | x | Y | . | Y | Y | Y | Y |
| balanced | S9-shared-commons | Y | x | x | . | . | Y | Y | Y |
| balanced | S9-private-commons | . | x | . | . | . | . | Y | . |
| fertile_valley | F | x | x | Y | Y | Y | Y | Y | Y |
| fertile_valley | S9-communal | x | x | Y | Y | Y | Y | Y | Y |
| fertile_valley | S9-shared | Y | Y | . | Y | Y | . | Y | Y |
| fertile_valley | S9-private | . | . | Y | Y | Y | . | Y | . |
| fertile_valley | S9-shared-commons | . | Y | . | x | Y | x | Y | Y |
| fertile_valley | S9-private-commons | x | . | . | . | Y | . | . | . |
| forested | F | Y | Y | x | Y | x | x | x | Y |
| forested | S9-communal | Y | x | x | Y | . | x | x | Y |
| forested | S9-shared | . | . | Y | Y | Y | Y | x | Y |
| forested | S9-private | . | x | Y | . | Y | . | x | Y |
| forested | S9-shared-commons | Y | . | . | Y | Y | Y | Y | x |
| forested | S9-private-commons | . | x | Y | . | . | . | x | . |
| marginal | F | Y | . | Y | Y | x | x | x | x |
| marginal | S9-communal | Y | . | Y | Y | x | x | x | x |
| marginal | S9-shared | Y | Y | x | Y | . | x | x | x |
| marginal | S9-private | Y | . | . | x | . | x | x | Y |
| marginal | S9-shared-commons | Y | x | Y | Y | . | x | x | x |
| marginal | S9-private-commons | . | . | . | x | . | x | x | . |
| rocky_highland | F | Y | Y | x | x | x | x | x | x |
| rocky_highland | S9-communal | Y | Y | x | x | x | x | x | x |
| rocky_highland | S9-shared | . | Y | x | x | x | x | x | x |
| rocky_highland | S9-private | . | . | x | x | x | x | . | x |
| rocky_highland | S9-shared-commons | . | Y | x | x | x | x | x | x |
| rocky_highland | S9-private-commons | . | . | . | x | x | x | x | x |
