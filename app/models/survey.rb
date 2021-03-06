class Survey < ApplicationRecord
  belongs_to :creator, class_name: User
  belongs_to :article
  has_many :votes

  TYPE_ANONYMOUS = 4

  TYPE_SHOW_RESULT_MASK = 3
  TYPE_SHOW_RESULT_TO_PUBLIC = 0
  TYPE_SHOW_RESULT_TO_VOTER = 1
  TYPE_SHOW_RESULT_AFTER_FINISH = 2

  def anonymous?
    self.survey_type & TYPE_ANONYMOUS != 0
  end

  def set_anonymous
    self.survey_type |= TYPE_ANONYMOUS
  end

  def show_result_type
    ["public", "voter", "finish"][self.survey_type & TYPE_SHOW_RESULT_MASK]
  end

  def set_show_result_type(label)
    show_result_type = {
      "public" => 0,
      "voter" => 1,
      "finish" => 2
    }[label]
    self.survey_type |= show_result_type if show_result_type
  end

  def add_vote(vote_content)
    begin
      data = JSON.parse(self.content).zip(JSON.parse(vote_content)).map do |question, answer|
        return false if question["type"] == "select-one" and answer.size != 1
        return false if question["type"] == "select-many" and answer.empty?
        count = question["count"] || [0] * question["choices"].size
        answer.each do |index|
          count[index] ||= 0
          count[index] += 1
        end
        question["count"] = count
        question
      end
      self.update_attributes(content: data.to_json)
    rescue
      false
    end
  end

  def voted(user_id)
    self.votes.where(voter_id: user_id).any?
  end

  def content_with_result(user_id)
    data = JSON.parse(self.content)
    show_result = case self.survey_type & TYPE_SHOW_RESULT_MASK
    when TYPE_SHOW_RESULT_TO_PUBLIC
      true
    when TYPE_SHOW_RESULT_TO_VOTER
      voted(user_id)
    when TYPE_SHOW_RESULT_AFTER_FINISH
      DateTime.now > self.end_time
    else
      false
    end
    data.map do |question|
      if show_result
        question["count"] ||= [0] * question["choices"].size
        question
      else
        question.except("count")
      end
    end
  end
end
