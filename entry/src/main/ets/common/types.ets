
export interface notice {
  notice_id: number
  museum_id: number
  notice_title: string
  notice_time: Date
  notice_author: string
  notice_content: string
  create_time: Date
  update_time: Date
  content : Array< string >
}