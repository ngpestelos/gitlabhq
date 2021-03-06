module MergeRequests
  # MergeService class
  #
  # Do git merge and in case of success
  # mark merge request as merged and execute all hooks and notifications
  # Executed when you do merge via GitLab UI
  #
  class MergeService < MergeRequests::BaseService
    attr_reader :merge_request, :commit_message

    def execute(merge_request, commit_message)
      @commit_message = commit_message
      @merge_request = merge_request

      unless @merge_request.mergeable?
        return error('Merge request is not mergeable')
      end

      merge_request.in_locked_state do
        if merge_changes
          after_merge
          success
        else
          error('Can not merge changes')
        end
      end
    end

    private

    def merge_changes
      if sha = commit
        after_commit(sha, merge_request.target_branch)
      end
    end

    def commit
      committer = repository.user_to_comitter(current_user)

      options = {
        message: commit_message,
        author: committer,
        committer: committer
      }

      repository.merge(merge_request.source_sha, merge_request.target_branch, options)
    end

    def after_commit(sha, branch)
      PostCommitService.new(project, current_user).execute(sha, branch)
    end

    def after_merge
      MergeRequests::PostMergeService.new(project, current_user).execute(merge_request)
    end
  end
end
