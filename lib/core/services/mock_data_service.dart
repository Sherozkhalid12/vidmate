import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/message_model.dart';

/// Mock data service for frontend development
class MockDataService {
  // Mock users
  static final List<UserModel> mockUsers = [
    UserModel(
      id: '1',
      username: 'techcreator',
      displayName: 'Tech Creator',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      bio: 'Creating amazing tech content 🚀',
      followers: 125000,
      following: 450,
      posts: 234,
      isOnline: true,
    ),
    UserModel(
      id: '2',
      username: 'designer_life',
      displayName: 'Designer Life',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
      bio: 'UI/UX Designer | Creative Director',
      followers: 89000,
      following: 320,
      posts: 156,
      isOnline: false,
    ),
    UserModel(
      id: '3',
      username: 'traveler',
      displayName: 'World Traveler',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      bio: 'Exploring the world one destination at a time ✈️',
      followers: 45000,
      following: 890,
      posts: 567,
      isOnline: true,
    ),
    UserModel(
      id: '4',
      username: 'fitness_guru',
      displayName: 'Fitness Guru',
      avatarUrl: 'https://i.pravatar.cc/150?img=4',
      bio: 'Fitness coach | Nutrition expert',
      followers: 67000,
      following: 234,
      posts: 189,
      isOnline: false,
    ),
    UserModel(
      id: '5',
      username: 'music_producer',
      displayName: 'Music Producer',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      bio: 'Making beats and vibes 🎵',
      followers: 234000,
      following: 567,
      posts: 445,
      isOnline: true,
    ),
  ];

  // Mock posts
  static List<PostModel> getMockPosts() {
    return [
      PostModel(
        id: '1',
        author: mockUsers[0],
        imageUrl: 'https://picsum.photos/800/600?random=1',
        caption: 'Just launched our new product! 🚀 Check it out and let me know what you think.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 1234,
        comments: 89,
        shares: 45,
        isLiked: false,
        isVideo: false,
      ),
      PostModel(
        id: '2',
        author: mockUsers[1],
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        thumbnailUrl: 'https://picsum.photos/800/600?random=2',
        caption: 'Behind the scenes of our latest design project ✨',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        likes: 5678,
        comments: 234,
        shares: 123,
        isLiked: true,
        videoDuration: const Duration(minutes: 3, seconds: 45),
        isVideo: true,
      ),
      PostModel(
        id: '3',
        author: mockUsers[2],
        imageUrl: 'https://picsum.photos/800/600?random=3',
        caption: 'Sunset in Santorini 🌅 This view never gets old.',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        likes: 8900,
        comments: 456,
        shares: 234,
        isLiked: false,
        isVideo: false,
      ),
      PostModel(
        id: '4',
        author: mockUsers[3],
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        thumbnailUrl: 'https://picsum.photos/800/600?random=4',
        caption: 'Morning workout routine 💪 Start your day right!',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        likes: 3456,
        comments: 123,
        shares: 67,
        isLiked: true,
        videoDuration: const Duration(minutes: 5, seconds: 30),
        isVideo: true,
      ),
      PostModel(
        id: '5',
        author: mockUsers[4],
        imageUrl: 'https://picsum.photos/800/600?random=5',
        caption: 'New track dropping soon! 🎵 Stay tuned...',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likes: 12345,
        comments: 890,
        shares: 456,
        isLiked: false,
        isVideo: false,
      ),
    ];
  }

  // Mock stories
  static List<StoryModel> getMockStories() {
    return [
      StoryModel(
        id: '1',
        author: mockUsers[0],
        mediaUrl: 'https://picsum.photos/400/800?random=10',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isViewed: false,
      ),
      StoryModel(
        id: '2',
        author: mockUsers[1],
        mediaUrl: 'https://picsum.photos/400/800?random=11',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isViewed: false,
      ),
      StoryModel(
        id: '3',
        author: mockUsers[2],
        mediaUrl: 'https://picsum.photos/400/800?random=12',
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        isViewed: true,
      ),
      StoryModel(
        id: '4',
        author: mockUsers[3],
        mediaUrl: 'https://picsum.photos/400/800?random=13',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        isViewed: false,
      ),
      StoryModel(
        id: '5',
        author: mockUsers[4],
        mediaUrl: 'https://picsum.photos/400/800?random=14',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isViewed: true,
      ),
    ];
  }

  // Mock messages
  static List<MessageModel> getMockMessages(String chatId) {
    return [
      MessageModel(
        id: '1',
        sender: mockUsers[0],
        text: 'Hey! How are you doing?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
      MessageModel(
        id: '2',
        sender: mockUsers[1],
        text: 'I\'m doing great! Just finished a new design project.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        isRead: true,
      ),
      MessageModel(
        id: '3',
        sender: mockUsers[0],
        text: 'That sounds amazing! Can\'t wait to see it.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        isRead: true,
      ),
      MessageModel(
        id: '4',
        sender: mockUsers[1],
        mediaUrl: 'https://picsum.photos/400/400?random=20',
        text: '',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isRead: true,
        type: MessageType.image,
      ),
      MessageModel(
        id: '5',
        sender: mockUsers[0],
        text: 'Wow, this looks incredible! 🔥',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
    ];
  }

  // Mock notifications
  static List<Map<String, dynamic>> getMockNotifications() {
    return [
      {
        'id': '1',
        'type': 'like',
        'user': mockUsers[0],
        'postId': '1',
        'text': 'liked your post',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'isRead': false,
      },
      {
        'id': '2',
        'type': 'comment',
        'user': mockUsers[1],
        'postId': '1',
        'text': 'commented: "This is amazing!"',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
        'isRead': false,
      },
      {
        'id': '3',
        'type': 'follow',
        'user': mockUsers[2],
        'text': 'started following you',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'isRead': true,
      },
      {
        'id': '4',
        'type': 'like',
        'user': mockUsers[3],
        'postId': '2',
        'text': 'liked your video',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': true,
      },
    ];
  }
}


