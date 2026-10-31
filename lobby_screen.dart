import 'dart:math';
import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'login_screen.dart';

class LobbyScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const LobbyScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = userData['is_admin'] ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${userData['username']} (${userData['country'] ?? 'KR'}) ${isAdmin ? "👑[관리자]" : ""}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.style), text: '1:1 대전/결승'),
              Tab(icon: Icon(Icons.emoji_events), text: '월드 랭킹'),
              Tab(icon: Icon(Icons.public), text: '통합 게시판'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GameLobbyTab(userData: userData),
            LeaderboardTab(currentUser: userData['username']),
            BoardTab(currentUser: userData['username'], country: userData['country'] ?? 'KR'),
          ],
        ),
      ),
    );
  }
}

// 🎮 1:1 일반 대전 및 결승전 방 생성 & 로비 탭
class GameLobbyTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  const GameLobbyTab({super.key, required this.userData});

  Future<void> _createRoom(BuildContext context, {required bool isFinals}) async {
    final myCard = Random().nextInt(10) + 1;
    try {
      final res = await supabase.from('rooms').insert({
        'host_name': userData['username'],
        'host_card': myCard,
        'status': 'waiting',
        'is_finals': isFinals,
      }).select().single();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PokerGameScreen(
              roomId: res['id'],
              isHost: true,
              myName: userData['username'],
              isFinals: isFinals,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('방 생성 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = userData['is_admin'] ?? false;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin) ...[
            FloatingActionButton.extended(
              heroTag: 'btnFinals',
              onPressed: () => _createRoom(context, isFinals: true),
              label: const Text('👑 결승 방 개설'),
              icon: const Icon(Icons.emoji_events),
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            heroTag: 'btnNormal',
            onPressed: () => _createRoom(context, isFinals: false),
            label: const Text('일반 대전 방 생성'),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: StreamBuilder<List>>(
        stream: supabase.from('rooms').stream(primaryKey: ['id']).eq('status', 'waiting'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data ?? [];
          if (rooms.isEmpty) {
            return const Center(child: Text('현재 대기 중인 방이 없습니다.\n방을 만들어 보세요!'));
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final bool isFinals = room['is_finals'] ?? false;

              return Card(
                color: isFinals ? Colors.amber.shade50 : null,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: isFinals
                    ? RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  leading: Icon(
                    isFinals ? Icons.emoji_events : Icons.casino,
                    color: isFinals ? Colors.amber.shade900 : Colors.brown,
                    size: 36,
                  ),
                  title: Text(
                    '${isFinals ? "👑 [결승전] " : ""}${room['host_name']} 님의 방',
                    style: TextStyle(fontWeight: isFinals ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(isFinals ? 'WSC 월드컵 공식 결승 매치' : '상태: 상대방 참가 대기 중...'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFinals ? Colors.amber.shade800 : null,
                      foregroundColor: isFinals ? Colors.white : null,
                    ),
                    onPressed: () async {
                      final guestCard = Random().nextInt(10) + 1;
                      await supabase.from('rooms').update({
                        'guest_name': userData['username'],
                        'guest_card': guestCard,
                        'status': 'playing',
                      }).eq('id', room['id']);

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PokerGameScreen(
                              roomId: room['id'],
                              isHost: false,
                              myName: userData['username'],
                              isFinals: isFinals,
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(isFinals ? '결승 입장' : '입장하기'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ♠️ 1:1 인디언 포커 게임 화면
class PokerGameScreen extends StatelessWidget {
  final int roomId;
  final bool isHost;
  final String myName;
  final bool isFinals;

  const PokerGameScreen({
    super.key,
    required this.roomId,
    required this.isHost,
    required this.myName,
    required this.isFinals,
  });

  Future<void> _updateScoresAndFinish(Map<String, dynamic> room) async {
    final String hostName = room['host_name'];
    final String? guestName = room['guest_name'];
    final int hostCard = room['host_card'] ?? 0;
    final int guestCard = room['guest_card'] ?? 0;

    if (guestName == null) return;

    String winner = 'draw';
    if (hostCard > guestCard) {
      winner = hostName;
    } else if (hostCard < guestCard) {
      winner = guestName;
    }

    await supabase.from('rooms').update({
      'status': 'finished',
      'winner': winner,
    }).eq('id', roomId);

    if (winner == 'draw') {
      await _addPointAndResult(hostName, isWin: false, isDraw: true);
      await _addPointAndResult(guestName, isWin: false, isDraw: true);
    } else {
      final String loser = (winner == hostName) ? guestName : hostName;
      await _addPointAndResult(winner, isWin: true, isDraw: false);
      await _addPointAndResult(loser, isWin: false, isDraw: false);
    }
  }

  Future<void> _addPointAndResult(String username, {required bool isWin, required bool isDraw}) async {
    try {
      final user = await supabase.from('users').select().eq('username', username).single();

      final int currentWins = user['wins'] ?? 0;
      final int currentDraws = user['draws'] ?? 0;
      final int currentLosses = user['losses'] ?? 0;
      final int currentPoints = user['points'] ?? 0;

      // 결승전은 2배 승점(6점), 일반전은 3점 부여
      final int winPoints = isFinals ? 6 : 3;
      final int drawPoints = isFinals ? 2 : 1;

      if (isWin) {
        await supabase.from('users').update({
          'wins': currentWins + 1,
          'points': currentPoints + winPoints,
        }).eq('username', username);
      } else if (isDraw) {
        await supabase.from('users').update({
          'draws': currentDraws + 1,
          'points': currentPoints + drawPoints,
        }).eq('username', username);
      } else {
        await supabase.from('users').update({
          'losses': currentLosses + 1,
        }).eq('username', username);
      }
    } catch (e) {
      debugPrint('점수 업데이트 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder?>(
      stream: supabase.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).map((list) => list.firstOrNull),
      builder: (context, snapshot) {
        final room = snapshot.data;
        if (room == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final String opponentName = isHost ? (room['guest_name'] ?? '대기 중...') : room['host_name'];
        final int? opponentCard = isHost ? room['guest_card'] : room['host_card'];
        final int? myCard = isHost ? room['host_card'] : room['guest_card'];
        final String status = room['status'] ?? 'waiting';

        return Scaffold(
          appBar: AppBar(
            title: Text('${isFinals ? "👑 [결승전] " : ""}포커 대전 (#$roomId)'),
            backgroundColor: isFinals ? Colors.amber.shade100 : null,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('상대방: $opponentName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: isFinals ? Colors.amber.shade200 : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        opponentCard != null ? '$opponentCard' : '?',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        status == 'finished' ? '$myCard' : '🔒',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('나: $myName (내 카드는 숨겨짐)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 32),

                  if (status == 'waiting')
                    const Text('상대방의 입장을 기다리고 있습니다...')
                  else if (status == 'playing')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                      onPressed: () => _updateScoresAndFinish(room),
                      child: const Text('승부 확인 및 결과 DB 반영'),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          room['winner'] == 'draw'
                              ? '무승부!'
                              : '🎉 챔피언: ${room['winner']} (${isFinals ? "+6점" : "+3점"} 획득)',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('로비로 돌아가기 (랭킹 확인)'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 🏆 실시간 월드 랭킹 탭
class LeaderboardTab extends StatelessWidget {
  final String currentUser;
  const LeaderboardTab({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List>>(
      stream: supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .order('points', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('랭킹 데이터를 불러올 수 없습니다.'));
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('등록된 유저가 없습니다.'));
        }

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final user = list[index];
            final isMe = user['username'] == currentUser;

            return ListTile(
              tileColor: isMe ? Colors.amber.shade50 : null,
              leading: CircleAvatar(
                backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade300 : Colors.brown.shade100),
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              title: Text(
                '${user['country'] ?? ''} ${user['username']}${user['is_admin'] == true ? ' 👑' : ''}',
                style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text('${user['wins'] ?? 0}승 ${user['draws'] ?? 0}무 ${user['losses'] ?? 0}패'),
              trailing: Text(
                '${user['points'] ?? 0} Pts',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown),
              ),
            );
          },
        );
      },
    );
  }
}

// 💬 전 세계 통합 게시판 탭
class BoardTab extends StatefulWidget {
  final String currentUser;
  final String country;
  const BoardTab({super.key, required this.currentUser, required this.country});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  void _openWriteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전 세계 통합 메시지 작성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '제목')),
            TextField(controller: _contentController, decoration: const InputDecoration(labelText: '내용')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.isNotEmpty && _contentController.text.isNotEmpty) {
                await supabase.from('posts').insert({
                  'author': '${widget.country} ${widget.currentUser}',
                  'title': _titleController.text,
                  'content': _contentController.text,
                });
                _titleController.clear();
                _contentController.clear();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('전송'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        onPressed: _openWriteDialog,
        child: const Icon(Icons.edit),
      ),
      body: StreamBuilder<List>>(
        stream: supabase.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('게시글을 가져올 수 없습니다.'));
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(child: Text('등록된 메시지가 없습니다.'));
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(post['content'] ?? ''),
                  trailing: Text(post['author'] ?? 'Global User', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
