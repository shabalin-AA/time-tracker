;; import
(use-modules (sqlite3)
             (ice-9 format)
             (ice-9 match)
             (ice-9 time)
             (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-13)
             (dotenv parser))


;; utils
(define-record-type <time-entry>
  (make-time-entry task date duration)
  time-entry?
  (task     time-entry-task)
  (date     time-entry-date)
  (duration time-entry-duration))

(define (row-to-entry row)
  (match row 
         (#(task date duration) 
          (make-time-entry task date duration))))

(define (sqlite-exec-collect db sql)
  (let ((rows '()) (stmt (sqlite-prepare db sql)))
    (sqlite-map (lambda (row) (set! rows (cons row rows))) stmt)
    (sqlite-finalize stmt)
    rows))

(define select-group "SELECT task, date, SUM(duration) as total_duration
                      FROM time_tracker
                      GROUP BY task, date
                      ORDER BY date DESC, total_duration DESC")

(define (format-duration secs)
  (let ((m (quotient (or secs 0) 60))) 
    (format #f "~ah ~am" (quotient m 60) (remainder m 60))))

(define (format-entry te) 
  (format #f "~10a | ~7a | ~a\n" 
          (time-entry-date te)
          (format-duration (time-entry-duration te)) 
          (time-entry-task te)))

(define (print-entries tes)
  (for-each 
    (lambda (time-entry) 
      (display (format-entry time-entry))) 
    tes))

(define (date-entries tes date)
  (filter 
    (lambda (te) (string-contains (time-entry-date te) date)) 
    tes))

(define (today-entries tes)
  (print-date-entries tes (strftime "%Y-%m-%d" (localtime (current-time)))))

(define (task-entries tes task)
  (filter 
    (lambda (te) (string-contains (time-entry-task te) task)) 
    tes))


;; main
(load-dotenv)
(define db (sqlite-open (getenv "DB_NAME")))

(let* ((rows (sqlite-exec-collect db select-group))
       (time-entries (map row-to-entry rows)))
  (print-entries time-entries)
)

(sqlite-close db)

;; end
