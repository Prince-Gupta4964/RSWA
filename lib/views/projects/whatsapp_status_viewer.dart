import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';

class WhatsAppStatusViewer extends StatefulWidget {
  final List<String> imageUrls;
  final String projectName;
  final String location;
  final String projectId;
  final VoidCallback? onNextProject;

  const WhatsAppStatusViewer({
    super.key,
    required this.imageUrls,
    required this.projectName,
    required this.location,
    required this.projectId,
    this.onNextProject,
  });

  @override
  State<WhatsAppStatusViewer> createState() => _WhatsAppStatusViewerState();
}

class _WhatsAppStatusViewerState extends State<WhatsAppStatusViewer> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  late AnimationController _hintAnimController;
  Timer? _timer;
  bool _isPaused = false;
  bool _showHint = true;
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

    _hintAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
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
      if (widget.onNextProject != null) {
        widget.onNextProject!();
      } else {
        Navigator.of(context).pop();
      }
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
    setState(() => _isPaused = true);
    _animController.stop();
  }

  void _onLongEnd(LongPressEndDetails details) {
    setState(() => _isPaused = false);
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
                              title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _shareProject() {
    final String shareText = 'Check out this amazing property: ${widget.projectName} at ${widget.location}!';
    Share.share(shareText);
  }

  @override
  void dispose() {
    _animController.dispose();
    _hintAnimController.dispose();
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
        body: const Center(child: Text('No images available', style: TextStyle(color: Colors.white))),
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
            // Swipe down -> Close
            Navigator.of(context).pop();
          } else if (details.delta.dy < -12) {
            // Swipe up -> Next property
            if (widget.onNextProject != null) {
              widget.onNextProject!();
            } else {
              Navigator.of(context).pop();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main Media Image
            Center(
              child: Image.network(
                currentUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // Top Dark Gradient Overlay for Status Bars & Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Bars
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                      // Header Profile & Close Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    widget.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
              ),
            ),

            // Instagram Reel Style Right-Side Vertical Action Buttons (Like, Favorite, Share)
            Positioned(
              right: 16,
              bottom: 110,
              child: StreamBuilder<DocumentSnapshot>(
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

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like / Heart Button & Count
                      GestureDetector(
                        onTap: () {
                          if (authVM.userUid.isNotEmpty) {
                            projectVM.toggleProjectFavorite(widget.projectId, authVM.userUid, List<String>.from(favs));
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isLiked ? Colors.red : Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _showLikedBySheet(context, favs),
                              child: Text(
                                '${favs.length} Likes',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Add to Favorite / Bookmark Button
                      GestureDetector(
                        onTap: () {
                          if (authVM.userUid.isNotEmpty) {
                            projectVM.toggleProjectFavorite(widget.projectId, authVM.userUid, List<String>.from(favs));
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: Icon(
                                isLiked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: isLiked ? const Color(0xFFFF6B22) : Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Save', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Share Button
                      GestureDetector(
                        onTap: _shareProject,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Icon(Icons.share_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 4),
                            const Text('Share', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Gradient Overlay for Details
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 30, 80, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.projectName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.location,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Swipe Up Gesture Hint Animation Overlay
            if (_showHint)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _hintAnimController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -8 * _hintAnimController.value),
                      child: Opacity(
                        opacity: 1.0 - (_hintAnimController.value * 0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 4),
                                Text('Swipe up for next property', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
