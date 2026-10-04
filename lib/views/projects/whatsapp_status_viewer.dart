import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';

class WhatsAppStatusViewer extends StatefulWidget {
  final List<String> imageUrls;
  final String projectName;
  final String location;
  final String projectId;

  const WhatsAppStatusViewer({
    super.key,
    required this.imageUrls,
    required this.projectName,
    required this.location,
    required this.projectId,
  });

  @override
  State<WhatsAppStatusViewer> createState() => _WhatsAppStatusViewerState();
}

class _WhatsAppStatusViewerState extends State<WhatsAppStatusViewer> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  Timer? _timer;
  bool _isPaused = false;
  final Duration _duration = const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: _duration);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextImage();
      }
    });
    _startStory();
  }

  void _startStory() {
    if (widget.imageUrls.isEmpty) return;
    _animController.forward(from: 0.0);
  }

  void _nextImage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _animController.forward(from: 0.0);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _animController.forward(from: 0.0);
    } else {
      _animController.forward(from: 0.0);
    }
  }

  void _onTapDown(TapDownDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.35) {
      _prevImage();
    } else {
      _nextImage();
    }
  }

  void _onLongStart(LongPressStartDetails details) {
    setState(() {
      _isPaused = true;
    });
    _animController.stop();
  }

  void _onLongEnd(LongPressEndDetails details) {
    setState(() {
      _isPaused = false;
    });
    _animController.forward();
  }

  void _showLikedBySheet(BuildContext context, List<dynamic> uids) {
    setState(() => _isPaused = true);
    _animController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Liked by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: uids.isEmpty
                  ? const Center(child: Text('No likes yet', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: uids.length,
                      itemBuilder: (context, index) {
                        final uid = uids[index].toString();
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) async {
                            if (!doc.exists) {
                              final cpDoc = await FirebaseFirestore.instance.collection('cps').doc(uid).get();
                              if (!cpDoc.exists) {
                                return await FirebaseFirestore.instance.collection('customers').doc(uid).get();
                              }
                              return cpDoc;
                            }
                            return doc;
                          }),
                          builder: (context, userSnap) {
                            String userName = 'User';
                            if (userSnap.hasData && userSnap.data!.exists) {
                              final userData = userSnap.data!.data() as Map<String, dynamic>?;
                              userName = userData?['name'] ?? userData?['cpName'] ?? userData?['fullName'] ?? 'User';
                            }
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFF6B22),
                                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)), // ONLY user name as requested!
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() => _isPaused = false);
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context, listen: false);

    if (widget.imageUrls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('No images available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentUrl = widget.imageUrls[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongStart,
        onLongPressEnd: _onLongEnd,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 12) {
            // Swipe down -> Back to list screen
            Navigator.of(context).pop();
          } else if (details.delta.dy < -12) {
            // Swipe up -> Show liked by sheet
            FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get().then((doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                final favs = data['favUids'] ?? (data['propertyDetails']?['favUids'] ?? []);
                _showLikedBySheet(context, favs);
              }
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main Image
            Center(
              child: Image.network(
                currentUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // Top Status Bars & Header Info
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Bars (Moving / Animated)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: widget.imageUrls.asMap().entries.map((entry) {
                        int index = entry.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: index < _currentIndex
                                    ? 1.0
                                    : index == _currentIndex
                                        ? _animController.value
                                        : 0.0,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 2.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Header Info (Project Name, Location, Close Button)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFF6B22),
                          child: Text(
                            widget.projectName.isNotEmpty ? widget.projectName[0].toUpperCase() : 'P',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.location} • ${_currentIndex + 1}/${widget.imageUrls.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar: Like Count & Like Button
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Liked by count badge (Tap to view liked list)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
                    builder: (context, snapshot) {
                      List<dynamic> favs = [];
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        favs = data?['favUids'] ?? (data?['propertyDetails']?['favUids'] ?? []);
                      }
                      return GestureDetector(
                        onTap: () => _showLikedBySheet(context, favs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite_rounded, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Text('${favs.length} Likes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Like Button
                  StreamBuilder<DocumentSnapshot>(
                    stream: authVM.userUid.isNotEmpty 
                        ? FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      List<dynamic> favs = [];
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        favs = data?['favUids'] ?? (data?['propertyDetails']?['favUids'] ?? []);
                      }
                      final bool isLiked = authVM.userUid.isNotEmpty && favs.contains(authVM.userUid);

                      return FloatingActionButton.small(
                        heroTag: 'status_like_fab',
                        backgroundColor: isLiked ? Colors.red : Colors.white24,
                        onPressed: () {
                          if (authVM.userUid.isNotEmpty) {
                            projectVM.toggleProjectFavorite(widget.projectId, authVM.userUid, List<String>.from(favs));
                          }
                        },
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
