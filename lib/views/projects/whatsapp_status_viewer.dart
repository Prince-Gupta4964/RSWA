import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/project_model.dart';

class WhatsAppStatusViewer extends StatefulWidget {
  final String? videoUrl;
  final List<String> imageUrls;
  final String projectName;
  final String location;
  final String projectId;
  final List<ProjectModel>? projects;
  final int? initialIndex;

  const WhatsAppStatusViewer({
    super.key,
    this.videoUrl,
    required this.imageUrls,
    required this.projectName,
    required this.location,
    required this.projectId,
    this.projects,
    this.initialIndex,
  });

  @override
  State<WhatsAppStatusViewer> createState() => _WhatsAppStatusViewerState();
}

class _WhatsAppStatusViewerState extends State<WhatsAppStatusViewer> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex ?? 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects != null && widget.projects!.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.projects!.length,
          itemBuilder: (context, index) {
            final proj = widget.projects![index];
            final details = proj.propertyDetails;
            final displayImage = (proj.coverImage ?? details['coverImage'])?.toString().trim();
            final imageUrls = details['imageUrls'] is Iterable ? List<String>.from(details['imageUrls']) : [];
            final location = proj.displayLocation;

            final String? rawVideo = (details['projectVideo'] ?? proj.rawData['projectVideo'])?.toString().trim();
            final String? projectVideo = (rawVideo != null && (rawVideo.contains('youtube.com') || rawVideo.contains('youtu.be'))) ? rawVideo : null;

            final List<String> allImages = [];
            if (displayImage != null) allImages.add(displayImage);
            for (var img in imageUrls) {
              if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
            }
            final rawImgs = details['images'] is Iterable ? List<String>.from(details['images']) : [];
            for (var img in rawImgs) {
              if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
            }
            final highImgs = details['highlightsImages'] is Iterable ? List<String>.from(details['highlightsImages']) : [];
            for (var img in highImgs) {
              if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
            }
            final outImgs = details['outdoorsImages'] is Iterable ? List<String>.from(details['outdoorsImages']) : [];
            for (var img in outImgs) {
              if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
            }

            return _SingleStatusPage(
              videoUrl: projectVideo,
              imageUrls: allImages.isNotEmpty ? allImages : ['https://via.placeholder.com/600'],
              projectName: proj.projectName,
              location: location,
              projectId: proj.id,
              isFirstPage: index == 0,
              onPageComplete: () {
                if (index < widget.projects!.length - 1) {
                  _pageController.animateToPage(
                    index + 1,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _SingleStatusPage(
        videoUrl: widget.videoUrl,
        imageUrls: widget.imageUrls,
        projectName: widget.projectName,
        location: widget.location,
        projectId: widget.projectId,
        isFirstPage: true,
        onPageComplete: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _SingleStatusPage extends StatefulWidget {
  final String? videoUrl;
  final List<String> imageUrls;
  final String projectName;
  final String location;
  final String projectId;
  final bool isFirstPage;
  final VoidCallback onPageComplete;

  const _SingleStatusPage({
    this.videoUrl,
    required this.imageUrls,
    required this.projectName,
    required this.location,
    required this.projectId,
    required this.isFirstPage,
    required this.onPageComplete,
  });

  @override
  State<_SingleStatusPage> createState() => _SingleStatusPageState();
}

class _SingleStatusPageState extends State<_SingleStatusPage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  late AnimationController _hintAnimController;
  bool _isPaused = false;
  bool _showHint = true;
  final Duration _duration = const Duration(seconds: 4);

  bool get _hasVideo => widget.videoUrl != null && widget.videoUrl!.isNotEmpty && (widget.videoUrl!.contains('youtube.com') || widget.videoUrl!.contains('youtu.be'));
  int get _totalItems => (_hasVideo ? 1 : 0) + widget.imageUrls.length;

  String? get _videoId {
    if (widget.videoUrl == null) return null;
    try {
      final uri = Uri.parse(widget.videoUrl!);
      if (uri.host.contains('youtube.com')) {
        String? v = uri.queryParameters['v'];
        if (v == null && uri.pathSegments.isNotEmpty) {
          v = uri.pathSegments.last;
        }
        return v;
      } else if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();

    // 🚀 Track status view count for current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      if (authVM.userUid.isNotEmpty) {
        final String uid = authVM.userUid;
        final String name = authVM.userData?['name'] ?? authVM.userData?['cpName'] ?? authVM.userData?['fullName'] ?? 'User';
        final docRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
        docRef.update({
          'statusViews.$uid': FieldValue.increment(1),
          'statusViewNames.$uid': name,
        }).catchError((_) {
          docRef.set({
            'statusViews': {uid: 1},
            'statusViewNames': {uid: name},
          }, SetOptions(merge: true));
        });
      }
    });

    // 🚀 Register YouTube view factory for Web
    if (kIsWeb && _videoId != null) {
      try {
        final origin = Uri.base.origin;
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(
          'youtube-iframe-status-$_videoId',
          (int viewId) {
            final web.HTMLIFrameElement iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
            iframe.src = 'https://www.youtube.com/embed/$_videoId?autoplay=1&origin=$origin';
            iframe.style.border = 'none';
            iframe.style.width = '100%';
            iframe.style.height = '100%';
            iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
            return iframe;
          },
        );
      } catch (_) {}
    }

    // 🚀 Precache all images immediately for instant lazy loading / zero lag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var url in widget.imageUrls) {
        if (url.isNotEmpty && !url.contains('placeholder')) {
          precacheImage(NetworkImage(url), context).catchError((_) {});
        }
      }
    });

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
    if (_totalItems == 0) return;
    if (_currentIndex == 0 && _hasVideo) {
      _animController.stop();
    } else {
      _animController.forward(from: 0.0);
    }
  }

  void _nextImage() {
    if (_currentIndex < _totalItems - 1) {
      setState(() {
        _currentIndex++;
      });
      if (_currentIndex == 0 && _hasVideo) {
        _animController.stop();
      } else {
        _animController.forward(from: 0.0);
      }
    } else {
      widget.onPageComplete();
    }
  }

  void _prevImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      if (_currentIndex == 0 && _hasVideo) {
        _animController.stop();
      } else {
        _animController.forward(from: 0.0);
      }
    } else {
      if (_currentIndex == 0 && _hasVideo) {
        _animController.stop();
      } else {
        _animController.forward(from: 0.0);
      }
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
    if (!(_currentIndex == 0 && _hasVideo)) {
      _animController.forward();
    }
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
      if (mounted) {
        setState(() => _isPaused = false);
        if (!(_currentIndex == 0 && _hasVideo)) {
          _animController.forward();
        }
      }
    });
  }

  void _showViewsSheet(BuildContext context) {
    setState(() => _isPaused = true);
    _animController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> statusViews = {};
          Map<String, dynamic> statusViewNames = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            final d = snapshot.data!.data() as Map<String, dynamic>?;
            final rawViews = d?['statusViews'] ?? d?['propertyDetails']?['statusViews'];
            if (rawViews is Map) statusViews = Map<String, dynamic>.from(rawViews);
            final rawNames = d?['statusViewNames'] ?? d?['propertyDetails']?['statusViewNames'];
            if (rawNames is Map) statusViewNames = Map<String, dynamic>.from(rawNames);
          }

          final entries = statusViews.entries.toList();

          return Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Views (${entries.length} Viewers)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('No views yet', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final uid = entry.key;
                            final count = entry.value;
                            final name = statusViewNames[uid] ?? 'User';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFF6B22),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text('$name ($count)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isPaused = false);
        if (!(_currentIndex == 0 && _hasVideo)) {
          _animController.forward();
        }
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    if (_totalItems == 0) {
      return const Center(child: Text('No media available', style: TextStyle(color: Colors.white)));
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onLongPressStart: _onLongStart,
      onLongPressEnd: _onLongEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Main Media Item: Direct inline YouTube player if index 0 and has video, otherwise image stack
          _currentIndex == 0 && _hasVideo
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      height: MediaQuery.of(context).size.height * 0.55,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF6B22), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb && _videoId != null
                            ? HtmlElementView(viewType: 'youtube-iframe-status-$_videoId')
                            : Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final Uri uri = Uri.parse(widget.videoUrl!);
                                    canLaunchUrl(uri).then((canLaunch) {
                                      if (canLaunch) launchUrl(uri, mode: LaunchMode.externalApplication);
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Play YouTube Video'),
                                ),
                              ),
                      ),
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    for (int i = 0; i < widget.imageUrls.length; i++)
                      Offstage(
                        offstage: i != (_currentIndex - (_hasVideo ? 1 : 0)),
                        child: Center(
                          child: Image.network(
                            widget.imageUrls[i],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              if (i == (_currentIndex - (_hasVideo ? 1 : 0))) {
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              }
                              return const SizedBox.shrink();
                            },
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

          // 2. Top Dark Gradient Overlay for Status Bars & Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                        children: List.generate(_totalItems, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: index < _currentIndex ? 1.0 : (index == _currentIndex ? _animController.value : 0.0),
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B22)),
                                  minHeight: 2.5,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Header Details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Color(0xFFFF6B22), size: 12),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        widget.location,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
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

          // 3. Bottom Action Bar & Hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showHint && widget.isFirstPage)
                      FadeTransition(
                        opacity: _hintAnimController,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '💡 Tap left/right to navigate • Hold to pause • Swipe up/down for next property',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Views Button & Count
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
                          builder: (context, snapshot) {
                            Map<String, dynamic> statusViews = {};
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final d = snapshot.data!.data() as Map<String, dynamic>?;
                              final rawViews = d?['statusViews'] ?? d?['propertyDetails']?['statusViews'];
                              if (rawViews is Map) {
                                statusViews = Map<String, dynamic>.from(rawViews);
                              }
                            }
                            int totalViews = 0;
                            for (var val in statusViews.values) {
                              if (val is num) totalViews += val.toInt();
                            }

                            return InkWell(
                              onTap: () => _showViewsSheet(context),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$totalViews Views',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Like Button
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
                          builder: (context, snapshot) {
                            List<String> favUids = [];
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final d = snapshot.data!.data() as Map<String, dynamic>?;
                              final rawFavs = d?['favUids'] ?? d?['propertyDetails']?['favUids'];
                              if (rawFavs is Iterable) {
                                favUids = List<String>.from(rawFavs);
                              }
                            }
                            final bool isLiked = authVM.userUid.isNotEmpty && favUids.contains(authVM.userUid);

                            return InkWell(
                              onTap: () async {
                                if (authVM.userUid.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to like properties.')));
                                  return;
                                }
                                final docRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
                                if (isLiked) {
                                  await docRef.update({
                                    'favUids': FieldValue.arrayRemove([authVM.userUid]),
                                    'propertyDetails.favUids': FieldValue.arrayRemove([authVM.userUid]),
                                  });
                                } else {
                                  await docRef.update({
                                    'favUids': FieldValue.arrayUnion([authVM.userUid]),
                                    'propertyDetails.favUids': FieldValue.arrayUnion([authVM.userUid]),
                                  });
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${favUids.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Liked By Users List
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
                          builder: (context, snapshot) {
                            List<dynamic> favUids = [];
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final d = snapshot.data!.data() as Map<String, dynamic>?;
                              final rawFavs = d?['favUids'] ?? d?['propertyDetails']?['favUids'];
                              if (rawFavs is Iterable) {
                                favUids = List<dynamic>.from(rawFavs);
                              }
                            }
                            return InkWell(
                              onTap: () => _showLikedBySheet(context, favUids),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.people_outline_rounded, color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Liked By',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Share Button
                        InkWell(
                          onTap: _shareProject,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.share_rounded, color: Colors.white, size: 26),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Share',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
