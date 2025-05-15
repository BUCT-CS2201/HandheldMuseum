export interface ImageItem {
  image_id: number;
  suffix: string;
  status: number;
}

export interface UploadImageItem {
  image_id: string;
  suffix: string;
}

export interface APICommentItem {
  comment_id: number;
  content: string;
  create_time: string;
  username: string;
  parent_id?: number;
  reply_count: number;
  like_count: number;
  avatar?: string;
}

export interface APIDynamicResponse {
  dynamic_id: number;
  content: string;
  create_time: string;
  comment_status: number;
  like_count: number;
  reply_count: number;
  username: string;
  images: ImageItem[];
  comments: APICommentItem[];
}

export class CommentItem {
  id: number;
  user: string;
  content: string;
  time: string;
  parent_id?: number;
  reply_count: number;
  replies: CommentItem[];

  constructor(
    id: number,
    user: string,
    content: string,
    time: string,
    parent_id?: number,
    reply_count: number = 0,
    replies: CommentItem[] = []
  ) {
    this.id = id;
    this.user = user;
    this.content = content;
    this.time = time;
    this.parent_id = parent_id;
    this.reply_count = reply_count;
    this.replies = replies;
  }
}

export class DynamicItem {
  id: number;
  avatar: Resource;
  username: string;
  content: string;
  time: string;
  likes: number;
  isLiked: boolean;
  images: string[];
  comments: CommentItem[];
  showComments: boolean;
  reply_count: number;

  constructor(
    id: number,
    username: string,
    content: string,
    isoTime: string,
    likes: number = 0,
    images: string[],
    comments: CommentItem[] = [],
    isLiked: boolean = false,
    avatar: Resource = $r("app.media.default_avatar"),
    showComments: boolean = false,
    reply_count: number = 0
  ) {
    this.id = id;
    this.username = username;
    this.content = content;
    this.time = this.formatTime(isoTime);
    this.likes = likes;
    this.images = images;
    this.comments = comments;
    this.isLiked = isLiked;
    this.avatar = avatar;
    this.showComments = showComments;
    this.reply_count = reply_count;
  }

  private formatTime(isoTime: string): string {
    const date = new Date(isoTime);
    return `${date.getFullYear()}-${date.getMonth()+1}-${date.getDate()} ${date.getHours()}:${date.getMinutes()}`;
  }
} 